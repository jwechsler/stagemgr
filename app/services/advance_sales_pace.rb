# For each upcoming Active performance of a batch of productions: tickets sold
# so far against the share its theater typically has in hand this many days
# out (AdvanceSalesCurve.for_theater over the theater's earlier seasons),
# giving a projected final count and that count as a share of capacity. When
# the typical share is under MINIMUM_PROJECTABLE_SHARE the projection fields
# are nil ("too early") while days_out, sold and typical_share stay populated.
# A theater with under MINIMUM_CURVE_TICKETS of history uses the building-wide
# curve instead (source :building); with neither, that production's
# performances get no readings. A production whose sales are recorded
# externally gets no readings either: its counts are keyed in after the fact
# in batches, so a projection would mislead.
#
# The batch form runs one performance query and one sales query for every
# production at once, and each curve once per [theater, season]. HouseCount
# stores the result nightly (projected_seats, pace_share, ...) so listings
# read the snapshot rather than calling this per request.
class AdvanceSalesPace
  MINIMUM_CURVE_TICKETS = 1_000
  # Below this share of final sales typically in hand, dividing by the share
  # turns a handful of tickets into a wild projection; it is noise.
  MINIMUM_PROJECTABLE_SHARE = 0.10

  Reading = Struct.new(:performance_id, :days_out, :sold, :typical_share, :projected_final,
                       :capacity, :projected_pct_of_capacity, :source, keyword_init: true)

  # productions: an Array or a relation.
  # => { performance_id => Reading } across all of them; {} when none has
  # usable history and an upcoming Active performance.
  def self.for_productions(productions, as_of: Date.current)
    new(productions, as_of: as_of).readings
  end

  def initialize(productions, as_of: Date.current)
    # Batch-entered counts make a projection meaningless; skip the curve queries too.
    @productions = productions.to_a
                              .reject { |p| p.sales_recorded_externally? || p.season.nil? }
                              .index_by(&:id)
    @as_of = as_of
    @curves = {}
  end

  def readings
    return {} if @productions.empty?

    performances = upcoming_performances
    return {} if performances.empty?

    sold = sold_by_performance(performances.map { |_, production_id, _| production_id }.uniq)
    performances.each_with_object({}) do |(id, production_id, date), acc|
      production = @productions[production_id]
      chosen = curve_for(production)
      next if chosen.nil?

      acc[id] = reading_for(id, date, sold.fetch(id, 0), chosen, production.capacity)
    end
  end

  private

  # [[performance_id, production_id, performance_date], ...]; pluck skips the
  # default scope's allocation preload.
  def upcoming_performances
    Performance.where(production_id: @productions.keys, status: Performance::ACTIVE,
                      performance_date: @as_of..)
               .order(:performance_date)
               .pluck(:id, :production_id, :performance_date)
  end

  def curve_for(production)
    key = [production.theater_id, production.season]
    return @curves[key] if @curves.key?(key)

    @curves[key] = curve(production.theater, production.season)
  end

  # The theater's own curve, else the building's; nil when both are thin.
  def curve(theater, season)
    own = AdvanceSalesCurve.for_theater(theater, before_season: season)
    return own if own.tickets >= MINIMUM_CURVE_TICKETS

    building = AdvanceSalesCurve.for_building(before_season: season)
    building.tickets >= MINIMUM_CURVE_TICKETS ? building : nil
  end

  def sold_by_performance(production_ids)
    AdvanceSalesRows.fetch(production_ids: production_ids, from_date: @as_of)
                    .each_with_object(Hash.new(0)) { |row, acc| acc[row.performance_id] += row.tickets }
  end

  def reading_for(performance_id, performance_date, sold, chosen, capacity)
    days_out = (performance_date - @as_of).to_i
    share = chosen.share_at(days_out)
    projected = projectable?(share) ? (sold / share).round : nil # nil: too early to project
    pct = projected && capacity.to_i.positive? ? projected.to_f / capacity : nil
    Reading.new(performance_id: performance_id, days_out: days_out, sold: sold, typical_share: share,
                projected_final: projected, capacity: capacity, projected_pct_of_capacity: pct,
                source: chosen.source)
  end

  def projectable?(share)
    !share.nil? && share >= MINIMUM_PROJECTABLE_SHARE
  end
end
