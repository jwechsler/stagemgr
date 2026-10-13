class Admin::AnalysisController < Admin::ApplicationController
  before_action :authorize_analysis
  before_action :authorize_pass_analysis, only: :memberships

  PRODUCTION_ANALYSES = %w[rate_of_sales ticket_revenue audience].freeze
  LEGACY_SCALAR_KEYS = %i[target_production_id comparison_production_id].freeze
  LEGACY_ARRAY_KEYS  = %i[comparison_production_ids comparison_theater_ids].freeze
  # Shown when a bookmark names shows, theaters or seasons that are outside the
  # user's read scope or no longer exist, so the narrower result is not a surprise.
  NARROWED_NOTICE = 'Some of the bookmarked shows or theaters are not available and were left out.'.freeze

  # The tab pages replaced a single form whose analysis_type picked the
  # endpoint; old bookmarks of that form land on the matching tab.
  def index
    analysis = params[:analysis_type].to_s
    return redirect_to(rate_of_sales_admin_analysis_index_path) unless PRODUCTION_ANALYSES.include?(analysis)

    redirect_to public_send("#{analysis}_admin_analysis_index_path", legacy_picks)
  end

  # Production search for the analysis pickers lives on
  # Admin::ProductionsController#search / #resolve_group (shared
  # production picker endpoints, scope: analysis); theater search for the
  # theater multi-picker lives on Admin::TheatersController#search.

  # GET: the form, plus results once it has been submitted (see analysis_runnable?).
  def audience
    @single_theater = single_theater
    load_target_production
    load_comparison_theaters
    return unless analysis_runnable?(:comparison_theater_ids)

    if @comparison_theaters.empty?
      flash.now[:error] = 'Select at least one comparison theater before running an audience analysis.'
      return
    end
    warn_if_narrowed(@requested_comparison_theater_ids, @comparison_theaters.map(&:id))

    @results = AudienceAnalysis.new(@target_production, @comparison_theaters.map(&:id)).compute
  end

  # GET: the form, plus results once a current show is given; the historical
  # comparison is optional.
  def ticket_revenue
    load_target_production
    load_comparison_production
    return unless analysis_runnable?(:target_production_id)

    requested = requested_ids(:comparison_production_id)
    warn_if_narrowed(requested, @comparison_production ? [@comparison_production.id] : [])
    @target_result     = TicketRevenueAnalysis.new(@target_production).compute
    @comparison_result = @comparison_production ? TicketRevenueAnalysis.new(@comparison_production).compute : nil
  end

  FACILITY_SEGMENT_KEYS = %w[first_time_vs_building returning_vs_building three_plus_in_building].freeze

  def audience_export
    target = Production.accessible_by(current_ability, :read).find(params[:target_production_id])
    only_theater = single_theater
    comparison_theater_ids = if only_theater
                               [only_theater.id]
                             else
                               readable_theaters.where(id: requested_ids(:comparison_theater_ids)).pluck(:id)
                             end
    segment_key  = params[:segment_key].to_s
    window_label = params[:window_label].presence

    if FACILITY_SEGMENT_KEYS.include?(segment_key) && !current_user.is_administrator?
      flash[:error] = 'Only administrators can export facility-wide cohorts.'
      redirect_to audience_admin_analysis_index_path(target_production_id: target.id,
                                                     comparison_theater_ids: comparison_theater_ids) and return
    end

    Resque.enqueue(
      AudienceCohortExport,
      target.id,
      comparison_theater_ids,
      segment_key,
      window_label,
      can?(:view_email, Address),
      current_user.theater_ids,
      current_user.id
    )
    flash[:notice] =
      "Your cohort export is queued. You'll receive an email when it's ready, and it will also appear on the reports page."
    redirect_to audience_admin_analysis_index_path(target_production_id: target.id,
                                                   comparison_theater_ids: comparison_theater_ids)
  end

  # GET: the form, plus results once it has been submitted (see analysis_runnable?).
  def rate_of_sales
    load_target_production
    load_comparison_productions
    @extra_weeks = params[:extra_weeks].to_i
    return unless analysis_runnable?(:comparison_production_ids)

    if @comparison_productions.empty?
      flash.now[:error] = 'Select at least one comparison show.'
      return
    end
    warn_if_narrowed(@requested_comparison_ids, @comparison_productions.map(&:id))

    @results = RateOfSalesAnalysis.new(@target_production, @comparison_productions).compute(extra_weeks: @extra_weeks)
  end

  DEFAULT_MEMBERSHIP_RANGE = 12.months

  # GET: the offer/date form, plus results once the form has been submitted
  # (membership_offer_ids is present, even if only its blank hidden field), so
  # a run is bookmarkable.
  def memberships
    @ending_date = Date.current
    @starting_date = @ending_date - DEFAULT_MEMBERSHIP_RANGE + 1.day
    @selected_offers = []
    @selected_groups = []
    return unless params.key?(:membership_offer_ids)

    run_membership_analysis
  end

  # GET: the filter form, plus results once seasons have been submitted (even
  # if only the blank hidden field), so a run is bookmarkable.
  def advance_sales
    readable  = Production.accessible_by(current_ability, :read)
    @theaters = Theater.where(id: readable.select(:theater_id)).order(:name).to_a
    @seasons  = readable.where.not(season: nil).distinct.pluck(:season).sort.reverse
    @filters  = AdvanceSalesFilters.new(params, theaters: @theaters, seasons: @seasons)
    @single_theater = single_theater
    @offer_external = readable.exists?(sales_recorded_externally: true)
    return unless @filters.submitted?

    if @filters.valid?
      flash.now[:warning] = NARROWED_NOTICE if @filters.narrowed?
      @results = AdvanceSalesAnalysis.new(**@filters.to_h).compute
    else
      flash.now[:error] = @filters.error
    end
  end

  private

  # A production analysis runs once its form was submitted, marked by +marker+
  # being in the params (the forms carry it as a blank hidden field, so a
  # target-only link just pre-fills the form). A submitted show the user
  # cannot read is an error, not a 404.
  def analysis_runnable?(marker)
    return false unless params.key?(marker)

    if params[:target_production_id].blank?
      flash.now[:error] = 'Select a current show.'
      return false
    end
    return true if @target_production

    flash.now[:error] = 'That production could not be found.'
    false
  end

  def load_target_production
    @target_production = readable_productions.find_by(id: params[:target_production_id].presence)
  end

  def load_comparison_productions
    @requested_comparison_ids = requested_ids(:comparison_production_ids)
    @comparison_productions = if @requested_comparison_ids.empty?
                                []
                              else
                                readable_productions.where(id: @requested_comparison_ids).includes(:theater).to_a
                              end
  end

  def load_comparison_production
    @comparison_production = readable_productions.find_by(id: params[:comparison_production_id].presence)
  end

  # A user who can read only one theater gets no picker, so that theater is
  # always the comparison group; other submitted ids are dropped and warned of.
  def load_comparison_theaters
    @requested_comparison_theater_ids = requested_ids(:comparison_theater_ids)
    @comparison_theaters = if @single_theater
                             [@single_theater]
                           elsif @requested_comparison_theater_ids.empty?
                             []
                           else
                             readable_theaters.where(id: @requested_comparison_theater_ids).order(:name).to_a
                           end
  end

  # The legacy form's picks, non-blank only. Array keys accept a lone scalar
  # too, so an old link with comparison_theater_ids=3 keeps its pick; values
  # that are not strings (nested hashes) are dropped.
  def legacy_picks
    picks = LEGACY_SCALAR_KEYS.index_with { |key| params[key].presence if params[key].is_a?(String) }
    LEGACY_ARRAY_KEYS.each do |key|
      picks[key] = Array(params[key]).grep(String).compact_blank.presence
    end
    picks.compact
  end

  # The distinct non-blank ids submitted under +key+ (a scalar or an array).
  def requested_ids(key)
    Array(params[key]).compact_blank.map(&:to_i).uniq
  end

  # Warns when some +requested+ ids were dropped from +loaded_ids+ because the
  # user cannot read them or they no longer exist; the analysis still runs on
  # what remains.
  def warn_if_narrowed(requested, loaded_ids)
    flash.now[:warning] = NARROWED_NOTICE if (requested - loaded_ids).any?
  end

  def readable_productions
    Production.accessible_by(current_ability, :read)
  end

  def readable_theaters
    Theater.accessible_by(current_ability, :read)
  end

  # The one theater a Theater user can read, or nil when they can read several
  # (or none) or are Admin or Box Office staff, who keep the picker however
  # many theaters exist. The Audience and Advance Sales forms omit their
  # theater picker for such a user, and a blank selection means that theater.
  def single_theater
    return unless current_user.is_theater_user?

    theaters = readable_theaters.limit(2).to_a
    theaters.first if theaters.one?
  end

  # Offers picked one by one (or through a group that expanded in the picker)
  # arrive as membership_offer_ids; dynamic groups arrive as
  # membership_offer_groups and expand here, against the submitted dates.
  def run_membership_analysis
    readable_offers = MembershipOffer.accessible_by(current_ability, :read)
    requested_ids = Array(params[:membership_offer_ids]).compact_blank.map(&:to_i)
    @selected_offers = readable_offers.where(id: requested_ids)
                                      .sort_by { |offer| [offer.active? ? 0 : 1, offer.name.to_s] }
    @selected_groups = Array(params[:membership_offer_groups]) & MembershipAnalysis::DYNAMIC_GROUPS
    @starting_date = parse_date(params[:starting_date]) || @starting_date
    @ending_date = parse_date(params[:ending_date]) || @ending_date
    error = membership_analysis_error
    if error
      flash.now[:error] = error
      return
    end

    offer_ids = @selected_offers.map(&:id) |
                MembershipAnalysis.offer_ids_for_groups(@selected_groups, readable_offers, @starting_date, @ending_date)
    if offer_ids.empty?
      flash.now[:error] = 'No membership offers had active memberships between ' \
                          "#{@starting_date.to_formatted_s(:long)} and #{@ending_date.to_formatted_s(:long)}."
      return
    end

    @results = MembershipAnalysis.new(offer_ids, @starting_date, @ending_date).compute
  end

  def membership_analysis_error
    return 'Select at least one membership offer.' if @selected_offers.empty? && @selected_groups.empty?
    if parse_date(params[:starting_date]).nil? || parse_date(params[:ending_date]).nil?
      return 'Enter a valid start and end date.'
    end
    return 'The start date must be on or before the end date.' if @starting_date > @ending_date

    nil
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def authorize_analysis
    authorize! :perform_analysis, Analysis
  end

  def authorize_pass_analysis
    authorize! :analyze_passes, Analysis
  end
end
