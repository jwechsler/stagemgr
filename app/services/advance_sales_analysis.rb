# Advance-sales curves for a set of theaters and seasons, grouped by season,
# theater or production, with a single-ticket and a subscription-pass line
# per group, plus each production's run broken into weeks. Counting rules live
# in AdvanceSalesRows; share-in-hand maths in AdvanceSalesCurve.
#
# Run weeks count from the production's first playing date (first preview,
# else press opening, else opening, else its earliest performance): week 0
# is the first seven days, negative weeks are earlier, and anything before
# PRE_RUN_WEEK_FLOOR collapses into that week. A performance was "added
# later" when it was first activated after the run had started.
#
# A series or run week is "in progress" when any of its performances is dated
# today or later: only its early buyers exist so far, so its curve reads as
# buying further ahead than it will once those performances have played, and
# shifts toward same-day as the run completes.
class AdvanceSalesAnalysis
  COMPARE_BY         = %w[season theater production].freeze
  PRE_RUN_WEEK_FLOOR = -2       # performances earlier than this collapse into one pre-run week
  MAX_SERIES         = 16       # beyond this the chart is unreadable; keep the first MAX_SERIES
  CACHE_TTL          = 1.hour
  CACHE_PREFIX       = 'advance_sales_analysis/v2'.freeze
  DAYS_PER_WEEK      = 7
  SEGMENT_SUFFIXES   = { 'single' => ' – single tickets', 'pass' => ' – subscription passes' }.freeze
  IN_PROGRESS_SUFFIX = ' (in progress)'.freeze

  Result = Struct.new(:series, :productions, :tickets, :truncated, keyword_init: true) do
    def activity? = tickets.positive?
    def in_progress? = series.any?(&:in_progress?)
  end
  # curve: AdvanceSalesCurve
  Series = Struct.new(:key, :label, :segment, :tickets, :curve, :performance_count, :upcoming_performance_count,
                      keyword_init: true) do
    def in_progress? = upcoming_performance_count.to_i.positive?
  end
  ProductionRun = Struct.new(:production, :tickets, :added_later_count, :weeks, keyword_init: true) do
    def in_progress? = weeks.any? { |week| week.upcoming_count.positive? }
  end
  RunWeek = Struct.new(:index, :starts_on, :performance_count, :added_later_count, :upcoming_count, :tickets,
                       :avg_lead_days, :same_day_share, :over_two_weeks_share, keyword_init: true)

  def initialize(theater_ids:, seasons:, compare_by:, segment:, include_external: false)
    @theater_ids = Array(theater_ids).map(&:to_i).sort
    @seasons = Array(seasons).map(&:to_i).sort
    @compare_by = compare_by.to_s
    @segment = segment.to_s
    @include_external = include_external ? true : false
    validate!
  end

  def compute
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { uncached_compute }
  end

  private

  def validate!
    raise ArgumentError, "unknown compare_by #{@compare_by.inspect}" unless COMPARE_BY.include?(@compare_by)
    raise ArgumentError, "unknown segment #{@segment.inspect}" unless AdvanceSalesCurve::SEGMENT_CHOICES.include?(@segment)
  end

  # Date.current is in the key because "in progress" depends on it.
  def cache_key
    params = [@theater_ids, @seasons, @compare_by, @segment, @include_external, Date.current].inspect
    "#{CACHE_PREFIX}/#{Digest::MD5.hexdigest(params)}"
  end

  # AdvanceSalesRows reads an empty filter as "no restriction", so an empty
  # theater or season list must short-circuit rather than reach it.
  def uncached_compute
    return Result.new(series: [], productions: [], tickets: 0, truncated: false) if @theater_ids.empty? || @seasons.empty?

    rows = AdvanceSalesRows.fetch(theater_ids: @theater_ids, seasons: @seasons, include_external: @include_external)
    productions = Production.where(id: rows.map(&:production_id).uniq).includes(:theater).index_by(&:id)
    performances = performances_for(productions)
    series = build_series(rows, productions, performances.to_h { |(id, _, date, _)| [id, date] })
    Result.new(series: series.first(MAX_SERIES), truncated: series.size > MAX_SERIES,
               productions: build_production_runs(rows, productions, performances), tickets: rows.sum(&:tickets))
  end

  # [id, production_id, performance_date, activated_at] for every performance
  # of the given productions, shared by the series and the production runs.
  def performances_for(productions)
    Performance.unscoped.where(production_id: productions.keys)
               .pluck(:id, :production_id, :performance_date, :activated_at)
  end

  def upcoming?(date)
    date.present? && date >= Date.current
  end

  # :section: Series

  def build_series(rows, productions, performance_dates)
    labels = group_labels(rows, productions)
    grouped = rows.group_by { |row| group_key(row) }
    ordered_keys(labels.keys, productions).flat_map do |key|
      segments.filter_map { |segment| series_for(key, labels[key], segment, grouped[key], performance_dates) }
    end
  end

  def segments
    @segment == 'both' ? AdvanceSalesRows::SEGMENTS : [@segment]
  end

  def series_for(key, group_label, segment, group_rows, performance_dates)
    segment_rows = group_rows.select { |row| row.segment == segment }
    tickets = segment_rows.sum(&:tickets)
    return nil if tickets.zero?

    performance_ids = segment_rows.map(&:performance_id).uniq
    upcoming = performance_ids.count { |id| upcoming?(performance_dates[id]) }
    Series.new(key: key, label: series_label(group_label, segment, upcoming.positive?), segment: segment,
               tickets: tickets, curve: AdvanceSalesCurve.from_rows(segment_rows, source: :rows),
               performance_count: performance_ids.size, upcoming_performance_count: upcoming)
  end

  def series_label(group_label, segment, in_progress)
    label = @segment == 'both' ? "#{group_label}#{SEGMENT_SUFFIXES.fetch(segment)}" : group_label
    in_progress ? "#{label}#{IN_PROGRESS_SUFFIX}" : label
  end

  def group_key(row)
    case @compare_by
    when 'season' then row.season
    when 'theater' then row.theater_id
    else row.production_id
    end
  end

  def group_labels(rows, productions)
    keys = rows.map { |row| group_key(row) }.uniq
    case @compare_by
    when 'season' then keys.index_with(&:to_s)
    when 'theater' then Theater.where(id: keys).pluck(:id, :name).to_h
    else keys.index_with { |id| productions.fetch(id).picker_label }
    end
  end

  # Season newest first; theaters by name; productions newest season first,
  # then by name.
  def ordered_keys(keys, productions)
    case @compare_by
    when 'season' then keys.sort_by { |season| -season.to_i }
    when 'theater' then Theater.where(id: keys).order(:name).pluck(:id)
    else production_order(keys.map { |id| productions.fetch(id) }).map(&:id)
    end
  end

  def production_order(productions)
    productions.sort_by { |production| [-production.season.to_i, production.name.to_s] }
  end

  # :section: Production runs

  def build_production_runs(rows, productions, performances)
    performances = performances.group_by(&:second)
    rows_by_performance = rows.group_by(&:performance_id)
    production_order(productions.values).map do |production|
      production_run(production, performances.fetch(production.id, []), rows_by_performance)
    end
  end

  def production_run(production, performances, rows_by_performance)
    start = run_start(production, performances)
    weeks = performances.group_by { |(_, _, date, _)| week_index(date, start) }.sort.map do |index, perfs|
      run_week(index, start, perfs, rows_by_performance)
    end
    ProductionRun.new(production: production, tickets: weeks.sum(&:tickets),
                      added_later_count: weeks.sum(&:added_later_count), weeks: weeks)
  end

  # Production#first_playing_date falls back to a date ten years out when no
  # run dates are set, so the earliest performance stands in instead.
  def run_start(production, performances)
    [production.first_preview_at, production.press_opening_at, production.opening_at].compact.first ||
      performances.filter_map(&:third).min || Date.current
  end

  def week_index(date, start)
    return PRE_RUN_WEEK_FLOOR if date.nil?

    [(date - start).to_i.div(DAYS_PER_WEEK), PRE_RUN_WEEK_FLOOR].max
  end

  def run_week(index, start, perfs, rows_by_performance)
    week_rows = perfs.flat_map { |(id, _, _, _)| rows_by_performance.fetch(id, []) }
    tickets = week_rows.sum(&:tickets)
    RunWeek.new(index: index, starts_on: start + index.weeks, performance_count: perfs.size,
                added_later_count: perfs.count { |(_, _, _, activated_at)| added_later?(activated_at, start) },
                upcoming_count: perfs.count { |(_, _, date, _)| upcoming?(date) },
                tickets: tickets, **lead_stats(week_rows, tickets))
  end

  def added_later?(activated_at, start)
    activated_at.present? && activated_at.to_date > start
  end

  def lead_stats(week_rows, tickets)
    return { avg_lead_days: nil, same_day_share: nil, over_two_weeks_share: nil } if tickets.zero?

    {
      avg_lead_days: week_rows.sum { |row| row.lead_days * row.tickets }.to_f / tickets,
      same_day_share: week_rows.select { |row| row.lead_days.zero? }.sum(&:tickets).to_f / tickets,
      over_two_weeks_share: week_rows.select { |row| row.lead_days > AdvanceSalesCurve::OVER_TWO_WEEKS }
                                     .sum(&:tickets).to_f / tickets
    }
  end
end
