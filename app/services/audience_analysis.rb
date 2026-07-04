# Audience retention/growth metrics for a single production.
#
# Cohort = distinct address_ids of attendees of `target_production`. Each
# Address row in the system is already deduped at the data layer (the system
# merges duplicate address records), so address_id is the right identity key
# for "who is this person". Filters:
#   - Order is a paid TicketOrder (status PROCESSED/FULFILLED with at least
#     one non-comp ticket line item)
#   - Address has an email OR a street address (line1 + zipcode); records
#     with neither can't represent a real person and are excluded
#   - Address is NOT flagged "Not a ticket buyer" (placeholder = true)
#
# Anchor date = production's closing date if the production has closed,
# otherwise today. All comparison windows are measured backwards from this
# anchor. Per the product spec, orders whose performance falls AFTER the
# anchor are excluded entirely (a patron returning AFTER seeing this show
# does not retroactively make them a returning visitor for this analysis).
#
# `comparison_theaters` is an Array of theater_ids defining the comparison
# group. The "facility" scope (every theater in the system, unscoped by
# CanCan) is always computed alongside, as a separate set of metrics.
class AudienceAnalysis
  # Per-window lookbacks. The value is an ActiveSupport::Duration subtracted
  # from the anchor to get window_start, EXCEPT for the special :ever sentinel,
  # which sets window_start to an effectively-infinite past so every prior
  # production qualifies.
  WINDOWS = {
    '3 months' => 3.months,
    '6 months' => 6.months,
    '1 year' => 1.year,
    '3 years' => 3.years,
    '5 years' => 5.years,
    'Ever' => :ever
  }.freeze

  EVER_FLOOR = Date.new(1900, 1, 1).freeze

  attr_reader :target_production, :comparison_theaters

  def initialize(target_production, comparison_theaters)
    @target_production = target_production
    @comparison_theaters = comparison_theaters
  end

  def compute
    anchor = anchor_date
    cohort_address_ids = load_cohort_address_ids

    return empty_result(anchor) if cohort_address_ids.empty?

    # Cohort's lifetime attendance, deduped to (address_id => Set of production_ids).
    # Date of the customer's order doesn't matter here — what matters is which
    # productions they attended at all. We then intersect with productions
    # whose RUN overlaps each window.
    attended_by_address = load_cohort_attendance(cohort_address_ids)
    # All non-target productions with their run bounds + theater.
    productions_meta = load_productions_meta

    # Returning-attendee headline counts (computed once, not per-window).
    previous_productions = load_previous_comparison_productions(productions_meta, limit: 3)
    all_comparison_prod_ids = productions_meta.each_with_object(Set.new) do |(prod_id, (_, _, theater_id)), set|
      set << prod_id if in_comparison?(theater_id)
    end

    previous_productions.each { |p| p[:returning_count] = 0 }
    returning_any_count = 0
    cohort_address_ids.each do |address_id|
      attended = attended_by_address[address_id] || EMPTY_SET
      previous_productions.each do |prev|
        prev[:returning_count] += 1 if attended.include?(prev[:id])
      end
      returning_any_count += 1 if (attended & all_comparison_prod_ids).any?
    end

    metrics = {
      first_time_vs_comparison: {},
      returning_vs_comparison: {},
      dedicated_customers: {},
      two_plus_in_comparison: {},
      first_time_vs_building: {},
      returning_vs_building: {},
      three_plus_in_building: {}
    }

    productions_in_comparison = {}
    productions_in_building = {}

    WINDOWS.each do |label, duration|
      window_start = duration == :ever ? EVER_FLOOR : (anchor - duration)

      comparison_prod_ids = productions_overlapping(productions_meta, window_start, anchor, scope: :comparison)
      building_prod_ids   = productions_overlapping(productions_meta, window_start, anchor, scope: :building)

      counts = roll_up(cohort_address_ids, attended_by_address, comparison_prod_ids, building_prod_ids)
      counts.each { |k, v| metrics[k][label] = v }

      productions_in_comparison[label] = comparison_prod_ids.size
      productions_in_building[label]   = building_prod_ids.size
    end

    {
      anchor_date: anchor,
      cohort_size: cohort_address_ids.size,
      window_labels: WINDOWS.keys,
      metrics: metrics,
      productions_in_comparison: productions_in_comparison,
      productions_in_building: productions_in_building,
      previous_productions: previous_productions,
      returning_attendees_any_count: returning_any_count
    }
  end

  # Returns Set of address_ids belonging to a single cohort segment, suitable
  # for CSV export. Mirrors the bookkeeping in `roll_up` and the headline
  # loops in `compute`, but collects address_ids instead of incrementing
  # counters. Recomputes from source SQL each call.
  #
  # segment_key: Symbol or String. One of
  #   :cohort, :returning_any, "previous_production:<id>",
  #   :first_time_vs_comparison, :returning_vs_comparison,
  #   :dedicated_customers, :two_plus_in_comparison,
  #   :first_time_vs_building, :returning_vs_building,
  #   :three_plus_in_building.
  # window_label: one of WINDOWS.keys, or nil for non-windowed segments
  #   (:cohort, :returning_any, "previous_production:<id>").
  def cohort_for(segment_key, window_label = nil)
    key = segment_key.to_s
    cohort_address_ids = load_cohort_address_ids
    return Set.new if cohort_address_ids.empty?

    return cohort_address_ids if key == 'cohort'

    attended_by_address = load_cohort_attendance(cohort_address_ids)
    productions_meta = load_productions_meta

    if key == 'returning_any'
      all_comparison_prod_ids = productions_meta.each_with_object(Set.new) do |(prod_id, (_, _, theater_id)), set|
        set << prod_id if in_comparison?(theater_id)
      end
      return cohort_address_ids.select do |address_id|
        attended = attended_by_address[address_id] || EMPTY_SET
        (attended & all_comparison_prod_ids).any?
      end.to_set
    end

    if key.start_with?('previous_production:')
      prev_id = key.split(':', 2).last.to_i
      return cohort_address_ids.select do |address_id|
        attended = attended_by_address[address_id] || EMPTY_SET
        attended.include?(prev_id)
      end.to_set
    end

    # Per-window segment.
    raise ArgumentError, "window_label required for segment #{key}" if window_label.nil?

    duration = WINDOWS.fetch(window_label) { raise ArgumentError, "unknown window #{window_label}" }
    window_start = duration == :ever ? EVER_FLOOR : (anchor_date - duration)

    comparison_prod_ids = productions_overlapping(productions_meta, window_start, anchor_date, scope: :comparison)
    building_prod_ids   = productions_overlapping(productions_meta, window_start, anchor_date, scope: :building)
    comp_count = comparison_prod_ids.size

    cohort_address_ids.select do |address_id|
      attended = attended_by_address[address_id] || EMPTY_SET
      comp_visits     = (attended & comparison_prod_ids).size
      building_visits = (attended & building_prod_ids).size
      case key
      when 'first_time_vs_comparison' then comp_visits == 0
      when 'returning_vs_comparison'  then comp_visits >= 1
      when 'dedicated_customers'      then comp_count > 0 && comp_visits == comp_count
      when 'two_plus_in_comparison'   then comp_visits >= 2
      when 'first_time_vs_building'   then building_visits == 0
      when 'returning_vs_building'    then building_visits >= 1
      when 'three_plus_in_building'   then building_visits >= 3
      else
        raise ArgumentError, "unknown segment_key #{key}"
      end
    end.to_set
  end

  private

  def anchor_date
    target_production.closed? ? target_production.closing_at : Date.today
  end

  def comparison_theater_id_set
    @comparison_theater_id_set ||= Set.new(Array(comparison_theaters).map(&:to_i))
  end

  # Returns Set of address_ids — the deduped cohort. Two sources are unioned:
  #   (a) paid (non-comp) TicketOrders to the target production
  #   (b) the addresses_productions HABTM join, which is populated both by
  #       order fulfillment AND by manual attendance entries like mailing
  #       card imports (TicketOrder#update_attendance_record and
  #       MailingCardImport#perform — see app/models/orders/ticket_order.rb
  #       and app/models/resque_jobs/mailing_card_import.rb).
  #
  # The same identifying-info and placeholder filters apply to both sources:
  # the system already merges duplicate Address records at the data layer,
  # so address_id is the canonical "who" key. Addresses without any
  # identifying info (no email AND no street address) or flagged "Not a
  # ticket buyer" (placeholder=true) are excluded.
  def load_cohort_address_ids
    cohort_sql = <<~SQL
      SELECT DISTINCT combined.address_id
      FROM (
        SELECT orders.address_id
        FROM orders
        INNER JOIN performances ON performances.id = orders.performance_id
        WHERE orders.type = 'TicketOrder'
          AND orders.status IN (#{attending_status_sql})
          AND performances.production_id = #{target_production.id.to_i}
          AND EXISTS (
            SELECT 1 FROM line_items li
            INNER JOIN ticket_classes tc ON tc.id = li.ticket_class_id
            WHERE li.order_id = orders.id
              AND li.type = 'TicketLineItem'
              AND tc.complimentary = FALSE
          )
        UNION
        SELECT ap.address_id
        FROM addresses_productions ap
        WHERE ap.production_id = #{target_production.id.to_i}
      ) AS combined
      INNER JOIN addresses ON addresses.id = combined.address_id
      WHERE (addresses.placeholder IS NULL OR addresses.placeholder = FALSE)
        AND (
          (addresses.email IS NOT NULL AND addresses.email <> '')
          OR (addresses.line1 IS NOT NULL AND addresses.line1 <> ''
              AND addresses.zipcode IS NOT NULL AND addresses.zipcode <> '')
        )
    SQL

    Set.new(ActiveRecord::Base.connection.select_values(cohort_sql).map(&:to_i))
  end

  # Returns { address_id => Set[production_id] } — the set of OTHER
  # productions each cohort address has ever attended. Unions two sources:
  #   (a) ATTENDING_STATUSES orders (comp or paid — both count as attendance
  #       for cross-attendance purposes; only the cohort itself is
  #       comp-filtered)
  #   (b) the addresses_productions HABTM, which catches mailing-card and
  #       other non-order attendance records
  # No date filter: whether a given attendance "counts" for a window is
  # decided by whether the PRODUCTION'S RUN overlaps that window (see
  # productions_overlapping), not by when the order/record was created.
  def load_cohort_attendance(address_ids)
    return {} if address_ids.empty?

    quoted_ids = address_ids.to_a.join(',')
    target_id = target_production.id.to_i
    sql = <<~SQL
      SELECT DISTINCT combined.address_id, combined.production_id
      FROM (
        SELECT orders.address_id, productions.id AS production_id
        FROM orders
        INNER JOIN performances ON performances.id = orders.performance_id
        INNER JOIN productions  ON productions.id  = performances.production_id
        WHERE orders.type = 'TicketOrder'
          AND orders.status IN (#{attending_status_sql})
          AND orders.address_id IN (#{quoted_ids})
          AND productions.id <> #{target_id}
        UNION
        SELECT ap.address_id, ap.production_id
        FROM addresses_productions ap
        WHERE ap.address_id IN (#{quoted_ids})
          AND ap.production_id <> #{target_id}
      ) AS combined
    SQL

    grouped = Hash.new { |h, k| h[k] = Set.new }
    ActiveRecord::Base.connection.select_rows(sql).each do |addr_id, prod_id|
      grouped[addr_id.to_i] << prod_id.to_i
    end
    grouped
  end

  # Returns { production_id => [min_perf_date, max_perf_date, theater_id] }
  # for every non-target production with at least one performance. Used to
  # decide which productions' runs overlap each window.
  def load_productions_meta
    sql = <<~SQL
      SELECT productions.id, productions.theater_id,
             MIN(performances.performance_date) AS min_d,
             MAX(performances.performance_date) AS max_d
      FROM productions
      INNER JOIN performances ON performances.production_id = productions.id
      WHERE productions.id <> #{target_production.id.to_i}
      GROUP BY productions.id, productions.theater_id
    SQL

    result = {}
    ActiveRecord::Base.connection.select_rows(sql).each do |prod_id, theater_id, min_d, max_d|
      mind = min_d.is_a?(String) ? Date.parse(min_d) : min_d
      maxd = max_d.is_a?(String) ? Date.parse(max_d) : max_d
      result[prod_id.to_i] = [mind, maxd, theater_id.to_i]
    end
    result
  end

  # Top N most-recent productions (by max performance date) in the
  # comparison group whose entire run ended BEFORE the target production
  # opened. Used for the "Returning attendees (PREVIOUS PRODUCTION)"
  # headline rows. Returns [] if no qualifying prior productions exist.
  def load_previous_comparison_productions(productions_meta, limit:)
    target_start = target_production.first_playing_date
    return [] if target_start.nil?

    candidates = productions_meta.each_with_object([]) do |(prod_id, (_min_d, max_d, theater_id)), acc|
      next if max_d.nil?
      next unless max_d < target_start
      next unless in_comparison?(theater_id)

      acc << { id: prod_id, last_perf: max_d }
    end
    top = candidates.sort_by { |c| c[:last_perf] }.reverse.first(limit)
    return [] if top.empty?

    prods_by_id = Production.where(id: top.pluck(:id)).index_by(&:id)
    top.map do |c|
      prod = prods_by_id[c[:id]]
      next nil unless prod

      { id: prod.id, name: prod.name, last_perf: c[:last_perf] }
    end.compact
  end

  # Returns Set of production_ids whose [min_perf_date, max_perf_date]
  # overlaps [window_start, anchor]. Two ranges [a,b] and [c,d] overlap iff
  # a <= d AND c <= b — here that's min_d <= anchor AND window_start <= max_d.
  def productions_overlapping(productions_meta, window_start, anchor, scope:)
    productions_meta.each_with_object(Set.new) do |(prod_id, (min_d, max_d, theater_id)), set|
      next if min_d.nil? || max_d.nil?
      next unless min_d <= anchor && window_start <= max_d

      next if (scope == :comparison) && !in_comparison?(theater_id)

      set << prod_id
    end
  end

  def roll_up(cohort_address_ids, attended_by_address, comparison_prod_ids, building_prod_ids)
    counts = {
      first_time_vs_comparison: 0,
      returning_vs_comparison: 0,
      dedicated_customers: 0,
      two_plus_in_comparison: 0,
      first_time_vs_building: 0,
      returning_vs_building: 0,
      three_plus_in_building: 0
    }
    comp_count = comparison_prod_ids.size

    cohort_address_ids.each do |address_id|
      attended = attended_by_address[address_id] || EMPTY_SET
      comp_visits     = (attended & comparison_prod_ids).size
      building_visits = (attended & building_prod_ids).size

      counts[:first_time_vs_comparison]     += 1 if comp_visits == 0
      counts[:returning_vs_comparison]      += 1 if comp_visits >= 1
      # Dedicated = attended EVERY production whose run overlapped the
      # window in the comparison group. Trivially false when nothing ran.
      counts[:dedicated_customers]          += 1 if comp_count > 0 && comp_visits == comp_count
      counts[:two_plus_in_comparison]       += 1 if comp_visits >= 2
      counts[:first_time_vs_building]       += 1 if building_visits == 0
      counts[:returning_vs_building]        += 1 if building_visits >= 1
      counts[:three_plus_in_building]       += 1 if building_visits >= 3
    end

    counts
  end

  EMPTY_SET = Set.new.freeze

  def in_comparison?(theater_id)
    comparison_theater_id_set.include?(theater_id)
  end

  def attending_status_sql
    Order::ATTENDING_STATUSES.map { |s| ActiveRecord::Base.connection.quote(s) }.join(',')
  end

  def empty_result(anchor)
    metrics = {
      first_time_vs_comparison: {},
      returning_vs_comparison: {},
      dedicated_customers: {},
      two_plus_in_comparison: {},
      first_time_vs_building: {},
      returning_vs_building: {},
      three_plus_in_building: {}
    }
    zero_map = {}
    WINDOWS.each_key do |label|
      metrics.each_value { |h| h[label] = 0 }
      zero_map[label] = 0
    end

    {
      anchor_date: anchor,
      cohort_size: 0,
      window_labels: WINDOWS.keys,
      metrics: metrics,
      productions_in_comparison: zero_map.dup,
      productions_in_building: zero_map.dup,
      previous_productions: [],
      returning_attendees_any_count: 0
    }
  end
end
