# For each upcoming Active performance of a production: tickets sold so far
# against the share its theater typically has in hand this many days out
# (AdvanceSalesCurve.for_theater over the theater's earlier seasons), giving
# a projected final count and that count as a share of capacity. When the
# typical share is under MINIMUM_PROJECTABLE_SHARE the projection fields are
# nil ("too early") while days_out, sold and typical_share stay populated. A
# theater with under MINIMUM_CURVE_TICKETS of history uses the building-wide
# curve instead (source :building); with neither, there are no readings.
# A production whose sales are recorded externally gets no readings either:
# its counts are keyed in after the fact in batches, so a projection would
# mislead.
class AdvanceSalesPace
  MINIMUM_CURVE_TICKETS = 1_000
  # Below this share of final sales typically in hand, dividing by the share
  # turns a handful of tickets into a wild projection; it is noise.
  MINIMUM_PROJECTABLE_SHARE = 0.10

  Reading = Struct.new(:performance_id, :days_out, :sold, :typical_share, :projected_final,
                       :capacity, :projected_pct_of_capacity, :source, keyword_init: true)

  # => { performance_id => Reading }; {} when there is no usable history, no
  # upcoming Active performance, or the production's sales are recorded
  # externally.
  def self.for_production(production, as_of: Date.current)
    new(production, as_of: as_of).readings
  end

  def initialize(production, as_of: Date.current)
    @production = production
    @as_of = as_of
  end

  def readings
    # Batch-entered counts make a projection meaningless; skip the curve queries too.
    return {} if @production.sales_recorded_externally?
    return {} if @production.season.nil?

    performances = upcoming_performances
    return {} if performances.empty?

    chosen = curve
    return {} if chosen.nil?

    sold = sold_by_performance
    capacity = @production.capacity
    performances.to_h do |id, date|
      [id, reading_for(id, date, sold.fetch(id, 0), chosen, capacity)]
    end
  end

  private

  # [[performance_id, performance_date], ...]; pluck skips the default
  # scope's allocation preload.
  def upcoming_performances
    @production.performances
               .where(status: Performance::ACTIVE)
               .where(performance_date: @as_of..)
               .order(:performance_date)
               .pluck(:id, :performance_date)
  end

  # The theater's own curve, else the building's; nil when both are thin.
  def curve
    own = AdvanceSalesCurve.for_theater(@production.theater, before_season: @production.season)
    return own if own.tickets >= MINIMUM_CURVE_TICKETS

    building = AdvanceSalesCurve.for_building(before_season: @production.season)
    building.tickets >= MINIMUM_CURVE_TICKETS ? building : nil
  end

  def sold_by_performance
    AdvanceSalesRows.fetch(production_ids: [@production.id], from_date: @as_of)
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
