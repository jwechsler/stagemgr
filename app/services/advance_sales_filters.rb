# The advance_sales action's params, checked against the theaters and
# seasons the user may see, with defaults for a first visit.
class AdvanceSalesFilters
  DEFAULT_SEASON_COUNT = 2
  DEFAULT_COMPARE_BY   = 'season'.freeze
  DEFAULT_SEGMENT      = 'both'.freeze
  NO_SEASON_ERROR      = 'Select at least one season.'.freeze

  attr_reader :theater_ids, :seasons, :compare_by, :segment, :include_external, :error

  # theaters: Array<Theater> the user may read; seasons: Array<Integer> the
  # user may read, newest first.
  def initialize(params, theaters:, seasons:)
    @params = params
    @theater_ids = pick_theater_ids(theaters.map(&:id))
    @seasons = pick_seasons(seasons)
    @compare_by = AdvanceSalesAnalysis::COMPARE_BY.include?(params[:compare_by]) ? params[:compare_by] : DEFAULT_COMPARE_BY
    @segment = AdvanceSalesCurve::SEGMENT_CHOICES.include?(params[:segment]) ? params[:segment] : DEFAULT_SEGMENT
    @include_external = params[:include_external] == '1'
    @error = NO_SEASON_ERROR if submitted? && @seasons.empty?
  end

  def submitted?
    @params.key?(:seasons)
  end

  def valid?
    error.nil?
  end

  def to_h
    { theater_ids: theater_ids, seasons: seasons, compare_by: compare_by, segment: segment,
      include_external: include_external }
  end

  private

  # No theater picked means every permitted theater.
  def pick_theater_ids(permitted)
    picked = Array(@params[:theater_ids]).compact_blank.map(&:to_i) & permitted
    picked.empty? ? permitted : picked
  end

  def pick_seasons(permitted)
    return permitted.first(DEFAULT_SEASON_COUNT) unless submitted?

    Array(@params[:seasons]).compact_blank.map(&:to_i) & permitted
  end
end
