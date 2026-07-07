class Admin::AnalysisController < Admin::ApplicationController
  before_action :authorize_analysis

  def index
    if params[:target_production_id].present?
      @target_production = Production.accessible_by(current_ability, :read).find_by(id: params[:target_production_id])
    end
    if params[:comparison_production_ids].present?
      ids = Array(params[:comparison_production_ids]).compact_blank.map(&:to_i)
      @comparison_productions = Production.accessible_by(current_ability, :read).where(id: ids).includes(:theater)
    end
    if params[:comparison_theater_ids].present?
      ids = Array(params[:comparison_theater_ids]).compact_blank.map(&:to_i)
      @comparison_theaters = Theater.where(id: ids).order(:name).to_a
    end
    if params[:comparison_production_id].present?
      @comparison_production = Production.accessible_by(current_ability,
                                                        :read).find_by(id: params[:comparison_production_id])
    end
    @analysis_type = params[:analysis_type]
  end

  # Production search for the analysis pickers lives on
  # Admin::ProductionsController#search / #resolve_group (shared
  # production picker endpoints, scope: analysis).

  def search_theaters
    query = params[:q].to_s.strip
    return render(json: []) if query.blank?

    q = "%#{query.downcase}%"
    name_matches = Theater.where('LOWER(theaters.name) LIKE ?', q).limit(20)
    tag_matches  = Theater.joins(:theater_tags)
                          .where('LOWER(theater_tags.name) LIKE ?', q)
                          .distinct
                          .limit(20)

    seen_ids = {}
    results = []

    name_matches.order(:name).each do |t|
      next if seen_ids[t.id]

      seen_ids[t.id] = true
      results << { id: t.id, label: t.name, match_kind: 'name' }
    end

    # Also surface tag-keyed group entries (one row per matching tag), so the
    # operator can pick "every theater tagged X" in one click.
    matching_tags = TheaterTag.where('LOWER(name) LIKE ?', q).order(:name)
    seen_tag_keys = {}
    matching_tags.each do |tag|
      key = tag.name.to_s.downcase
      next if key.blank? || seen_tag_keys[key]

      seen_tag_keys[key] = true
      tag_theaters = Theater.tagged_with(tag.name).order(:name).pluck(:id, :name)
      next if tag_theaters.empty?

      results << {
        group_key: "tag:#{tag.name}",
        label: "All theaters tagged #{tag.name}",
        theaters: tag_theaters.map { |id, name| { id: id, name: name } }
      }
    end

    tag_matches.order(:name).each do |t|
      next if seen_ids[t.id]

      seen_ids[t.id] = true
      results << { id: t.id, label: t.name, match_kind: 'tag' }
    end

    render json: results
  end

  def audience
    @target_production = Production.accessible_by(current_ability, :read).find(params[:target_production_id])

    requested_ids = Array(params[:comparison_theater_ids]).compact_blank.map(&:to_i)
    @comparison_theaters = Theater.where(id: requested_ids).to_a

    if requested_ids.empty?
      flash[:error] = 'Select at least one comparison theater before running an audience analysis.'
      redirect_to admin_analysis_index_path(target_production_id: @target_production.id, analysis_type: 'audience')
      return
    end

    @results = AudienceAnalysis.new(@target_production, requested_ids).compute

    respond_to do |format|
      format.html
    end
  end

  def ticket_revenue
    @target_production = Production.accessible_by(current_ability, :read).find(params[:target_production_id])

    if params[:comparison_production_id].present?
      @comparison_production = Production.accessible_by(current_ability, :read)
                                         .find_by(id: params[:comparison_production_id])
    end

    @target_result     = TicketRevenueAnalysis.new(@target_production).compute
    @comparison_result = @comparison_production ? TicketRevenueAnalysis.new(@comparison_production).compute : nil

    respond_to do |format|
      format.html
    end
  end

  FACILITY_SEGMENT_KEYS = %w[first_time_vs_building returning_vs_building three_plus_in_building].freeze

  def audience_export
    target = Production.accessible_by(current_ability, :read).find(params[:target_production_id])
    comparison_theater_ids = Array(params[:comparison_theater_ids]).compact_blank.map(&:to_i)
    segment_key  = params[:segment_key].to_s
    window_label = params[:window_label].presence

    if FACILITY_SEGMENT_KEYS.include?(segment_key) && !current_user.is_administrator?
      flash[:error] = 'Only administrators can export facility-wide cohorts.'
      redirect_to admin_analysis_index_path(target_production_id: target.id, analysis_type: 'audience',
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
    redirect_to admin_analysis_index_path(target_production_id: target.id, analysis_type: 'audience',
                                          comparison_theater_ids: comparison_theater_ids)
  end

  def rate_of_sales
    @target_production = Production.accessible_by(current_ability, :read).find(params[:target_production_id])
    comparison_ids = Array(params[:comparison_production_ids]).compact_blank.map(&:to_i)
    @comparison_productions = Production.accessible_by(current_ability, :read).where(id: comparison_ids)

    @extra_weeks = params[:extra_weeks].to_i
    analysis = RateOfSalesAnalysis.new(@target_production, @comparison_productions)
    @results = analysis.compute(extra_weeks: @extra_weeks)

    respond_to do |format|
      format.html
    end
  end

  private

  def authorize_analysis
    authorize! :perform_analysis, Analysis
  end
end
