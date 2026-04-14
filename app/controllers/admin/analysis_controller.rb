class Admin::AnalysisController < Admin::ApplicationController
  before_action :authorize_analysis

  def index
    if params[:target_production_id].present?
      @target_production = Production.accessible_by(current_ability, :read).find_by(id: params[:target_production_id])
    end
    if params[:comparison_production_ids].present?
      ids = Array(params[:comparison_production_ids]).reject(&:blank?).map(&:to_i)
      @comparison_productions = Production.accessible_by(current_ability, :read).where(id: ids).includes(:theater)
    end
  end

  def search_productions
    query = params[:q].to_s.strip
    base_scope = Production.accessible_by(current_ability, :read)
                           .where.not(status: Production::PRESALE)

    productions = base_scope
                    .left_outer_joins(:theater)
                    .where("LOWER(productions.name) LIKE :q OR CAST(productions.season AS CHAR) LIKE :q OR LOWER(productions.production_code) LIKE :q OR LOWER(theaters.name) LIKE :q",
                           q: "%#{query.downcase}%")
                    .includes(:theater)
                    .order(season: :desc, name: :asc)
                    .limit(20)

    results = []

    # Add season group entries for matching seasons
    matching_seasons = base_scope
                         .where("CAST(productions.season AS CHAR) LIKE :q", q: "%#{query}%")
                         .distinct.pluck(:season).sort.reverse
    matching_seasons.each do |season|
      results << { group_key: "season:#{season}", label: "All shows in #{season}" }
    end

    # Add theater group entries — only theaters with accessible productions
    accessible_theater_ids = base_scope.distinct.pluck(:theater_id)
    matching_theaters = Theater.where(id: accessible_theater_ids)
                               .where("LOWER(name) LIKE :q", q: "%#{query.downcase}%")
    matching_theaters.each do |theater|
      results << { group_key: "theater:#{theater.id}", label: "All shows by #{theater.name}" }
    end

    # Add individual production results
    productions.each do |p|
      results << { id: p.id, label: "#{p.season} - #{p.name} (#{p.theater.name})", name: p.name, season: p.season, theater: p.theater.name }
    end

    render json: results
  end

  def resolve_group
    group_key = params[:group_key].to_s
    type, value = group_key.split(":", 2)

    base_scope = Production.accessible_by(current_ability, :read)
                           .where.not(status: Production::PRESALE)
                           .includes(:theater)
                           .order(season: :desc, name: :asc)

    productions = case type
                  when "season"
                    base_scope.where(season: value.to_i)
                  when "theater"
                    base_scope.where(theater_id: value.to_i)
                  else
                    Production.none
                  end

    render json: productions.map { |p|
      { id: p.id, label: "#{p.season} - #{p.name} (#{p.theater.name})", name: p.name, season: p.season, theater: p.theater.name }
    }
  end

  def rate_of_sales
    @target_production = Production.accessible_by(current_ability, :read).find(params[:target_production_id])
    comparison_ids = Array(params[:comparison_production_ids]).reject(&:blank?).map(&:to_i)
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
