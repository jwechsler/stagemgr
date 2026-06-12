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

  def search_productions
    query = params[:q].to_s.strip
    base_scope = Production.accessible_by(current_ability, :read)
                           .where.not(status: Production::PRESALE)

    productions = base_scope
                  .left_outer_joins(:theater)
                  .where('LOWER(productions.name) LIKE :q OR CAST(productions.season AS CHAR) LIKE :q OR LOWER(productions.production_code) LIKE :q OR LOWER(theaters.name) LIKE :q',
                         q: "%#{query.downcase}%")
                  .includes(:theater)
                  .order(season: :desc, name: :asc)
                  .limit(20)

    results = []

    # Add season group entries for matching seasons
    matching_seasons = base_scope
                       .where('CAST(productions.season AS CHAR) LIKE :q', q: "%#{query}%")
                       .distinct.pluck(:season).sort.reverse
    matching_seasons.each do |season|
      results << { group_key: "season:#{season}", label: "All shows in #{season}" }
    end

    # Add theater group entries — only theaters with accessible productions
    accessible_theater_ids = base_scope.distinct.pluck(:theater_id)
    matching_theaters = Theater.where(id: accessible_theater_ids)
                               .where('LOWER(name) LIKE :q', q: "%#{query.downcase}%")
    matching_theaters.each do |theater|
      results << { group_key: "theater:#{theater.id}", label: "All shows by #{theater.name}" }
    end

    # Add tag group entries — only tags on theaters with accessible productions.
    # Dedup case-insensitively, preserving the first casing we encounter.
    matching_tags = TheaterTag.where(theater_id: accessible_theater_ids)
                              .where('LOWER(name) LIKE :q', q: "%#{query.downcase}%")
                              .order(:name)
    seen_tag_keys = {}
    matching_tags.each do |tag|
      key = tag.name.to_s.downcase
      next if key.blank? || seen_tag_keys[key]

      seen_tag_keys[key] = true
      results << { group_key: "tag:#{tag.name}", label: "All shows tagged #{tag.name}" }
    end

    # Add individual production results
    productions.each do |p|
      results << { id: p.id, label: "#{p.season} - #{p.name} (#{p.theater.name})", name: p.name, season: p.season,
                   theater: p.theater.name, theater_id: p.theater_id }
    end

    render json: results
  end

  def resolve_group
    group_key = params[:group_key].to_s
    type, value = group_key.split(':', 2)

    base_scope = Production.accessible_by(current_ability, :read)
                           .where.not(status: Production::PRESALE)
                           .includes(:theater)
                           .order(season: :desc, name: :asc)

    productions = case type
                  when 'season'
                    base_scope.where(season: value.to_i)
                  when 'theater'
                    base_scope.where(theater_id: value.to_i)
                  when 'tag'
                    tagged_theater_ids = TheaterTag.where('LOWER(name) = ?', value.to_s.downcase)
                                                   .distinct.pluck(:theater_id)
                    base_scope.where(theater_id: tagged_theater_ids)
                  else
                    Production.none
                  end

    render json: productions.map { |p|
      { id: p.id, label: "#{p.season} - #{p.name} (#{p.theater.name})", name: p.name, season: p.season,
        theater: p.theater.name }
    }
  end

  def search_production
    query      = params[:q].to_s.strip
    exclude_id = params[:exclude_id].to_i

    base_scope = Production.accessible_by(current_ability, :read)
                           .where.not(status: Production::PRESALE)

    scope = base_scope
            .left_outer_joins(:theater)
            .where(
              'LOWER(productions.name) LIKE :q OR CAST(productions.season AS CHAR) LIKE :q OR LOWER(theaters.name) LIKE :q',
              q: "%#{query.downcase}%"
            )
            .includes(:theater)
            .order(season: :desc, name: :asc)
            .limit(20)

    scope = scope.where.not(id: exclude_id) if exclude_id > 0

    render json: scope.map { |p|
      {
        id: p.id,
        label: "#{p.season} - #{p.name} (#{p.theater.name})",
        name: p.name,
        season: p.season,
        theater: p.theater.name,
        theater_id: p.theater_id,
        status: p.status,
        closing_at: p.closing_at
      }
    }
  end

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
