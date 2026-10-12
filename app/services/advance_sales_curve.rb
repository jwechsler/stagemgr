# The share of a group's final ticket sales already in hand a given number
# of days before the performance, built from AdvanceSalesRows. A theater's
# curve (for_theater) is its own earlier seasons; the building curve
# (for_building) pools every in-house theater. Both are cached.
#
# "In hand at d days out" counts tickets whose root purchase was d or more
# days before the performance, so share_at(0) is 1.0 and the share falls to
# 0.0 beyond the earliest sale. Holds only plain values so it caches safely.
class AdvanceSalesCurve
  THRESHOLDS       = [60, 45, 30, 21, 14, 10, 7, 5, 3, 2, 1, 0].freeze # chart x-axis
  TABLE_THRESHOLDS = [30, 14, 7, 3, 1].freeze # comparison table
  OVER_TWO_WEEKS   = 14
  CACHE_TTL        = 1.hour
  SEGMENT_CHOICES  = %w[both single pass].freeze
  CACHE_PREFIX     = 'advance_sales_curve/v2'.freeze

  attr_reader :tickets, :performance_count, :source # source: :theater | :building | :rows

  # rows: Array<AdvanceSalesRows::Row>
  def self.from_rows(rows, source: :rows)
    new(rows, source: source)
  end

  def self.for_theater(theater, before_season:, segment: 'both')
    validate_segment!(segment)
    key = "#{CACHE_PREFIX}/theater/#{theater.id}/before/#{before_season}/#{segment}"
    Rails.cache.fetch(key, expires_in: CACHE_TTL) do
      rows = AdvanceSalesRows.fetch(theater_ids: [theater.id], before_season: before_season)
      from_rows(select_segment(rows, segment), source: :theater)
    end
  end

  def self.for_building(before_season:, segment: 'both')
    validate_segment!(segment)
    key = "#{CACHE_PREFIX}/building/before/#{before_season}/#{segment}"
    Rails.cache.fetch(key, expires_in: CACHE_TTL) do
      rows = AdvanceSalesRows.fetch(before_season: before_season)
      from_rows(select_segment(rows, segment), source: :building)
    end
  end

  def self.validate_segment!(segment)
    return if SEGMENT_CHOICES.include?(segment)

    raise ArgumentError, "unknown segment #{segment.inspect}; expected one of #{SEGMENT_CHOICES.join(', ')}"
  end

  def self.select_segment(rows, segment)
    segment == 'both' ? rows : rows.select { |r| r.segment == segment }
  end

  private_class_method :validate_segment!, :select_segment

  def initialize(rows, source: :rows)
    @source = source
    @by_lead = rows.each_with_object(Hash.new(0)) { |r, h| h[r.lead_days] += r.tickets }
    @tickets = @by_lead.values.sum
    @performance_count = rows.map(&:performance_id).uniq.size
    @max_lead = @by_lead.keys.max || 0
    @in_hand = build_in_hand
  end

  def empty?
    @tickets.zero?
  end

  def share_at(days_out)
    return nil if empty?

    @in_hand[days_out.clamp(0, @max_lead + 1)].to_f / @tickets
  end

  def same_day_share
    return nil if empty?

    @by_lead[0].to_f / @tickets
  end

  def thresholds_table
    THRESHOLDS.index_with { |d| share_at(d) }
  end

  def tickets_per_performance
    return nil if empty?

    @tickets.to_f / @performance_count
  end

  private

  # @in_hand[d] = tickets with lead_days >= d, for d in 0..max_lead + 1.
  def build_in_hand
    running = 0
    @max_lead.downto(0).each_with_object(Array.new(@max_lead + 2, 0)) do |d, acc|
      running += @by_lead[d]
      acc[d] = running
    end
  end
end
