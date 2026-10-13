# Tickets by how far ahead of the performance they were bought, on the
# HouseCount basis: TicketOrders in TicketOrderMergeable::SOLD_STATUSES, TicketLineItems with
# ticket_count > 0 on seat-holding, non-complimentary classes, for Active
# performances only (Private ones are not on sale to the public, Inactive
# ones not at all). The sale date
# is the root purchase: exchange_source_id / split_source_id are walked back
# to the first order and its created_at, converted from the host's storage
# zone to the app zone (Time.zone), gives the sale date. lead_days =
# performance_date - that date,
# floored at 0. Segment is 'pass' when the order or its root redeemed, for
# at least one ticket, a flex pass whose offer is tied to a theater or
# festival (the kind sold as a subscription); otherwise 'single'.
# Building-wide flex passes and memberships count as single tickets.
# membership_offers has no theater or festival column, so memberships are
# always single today; if a membership ever becomes theater-bound, the rule
# extends to it. Productions flagged sales_recorded_externally are left out
# unless include_external.
class AdvanceSalesRows
  Row = Struct.new(:performance_id, :production_id, :theater_id, :season, :segment, :lead_days, :tickets,
                   keyword_init: true)

  SEGMENTS          = %w[single pass].freeze
  PASS_PAYMENT_TYPE = 'FlexPassPayment'.freeze
  MAX_CHAIN_DEPTH   = 20 # a corrupt cyclic source chain degrades to the order's own date

  # Every filter is optional; nil means no restriction. An empty array is
  # treated like nil (no clause), not as "match nothing". Returns Array<Row>,
  # one per (performance, segment, lead_days), with integer fields.
  def self.fetch(theater_ids: nil, seasons: nil, before_season: nil, production_ids: nil,
                 performance_ids: nil, from_date: nil, include_external: false)
    sql = to_sql(theater_ids: theater_ids, seasons: seasons, before_season: before_season,
                 production_ids: production_ids, performance_ids: performance_ids, from_date: from_date,
                 include_external: include_external)
    ActiveRecord::Base.connection.select_all(sql).map { |h| build_row(h) }
  end

  # The sanitized SQL fetch runs; exposed for EXPLAIN and debugging.
  def self.to_sql(theater_ids: nil, seasons: nil, before_season: nil, production_ids: nil,
                  performance_ids: nil, from_date: nil, include_external: false)
    clauses, binds = filter_clauses(theater_ids: theater_ids, seasons: seasons, before_season: before_season,
                                    production_ids: production_ids, performance_ids: performance_ids,
                                    from_date: from_date, include_external: include_external)
    sql = base_sql.sub("/* filters */", clauses.map { |c| "AND #{c}" }.join(" "))
    ActiveRecord::Base.sanitize_sql_array(
      [sql, binds.merge(max_depth: MAX_CHAIN_DEPTH, pass_type: PASS_PAYMENT_TYPE,
                        sold: TicketOrderMergeable::SOLD_STATUSES, active: Performance::ACTIVE,
                        storage_tz: storage_time_zone, app_tz: app_time_zone)]
    )
  end

  # True when MySQL can convert into the app zone by name. Without the
  # time-zone tables CONVERT_TZ returns NULL and fetch falls back to the raw
  # storage-zone date; the spec asserts this so CI fails loudly instead.
  def self.time_zone_tables_loaded?
    conn = ActiveRecord::Base.connection
    conn.select_value("SELECT CONVERT_TZ('2000-01-01 00:00:00', 'UTC', #{conn.quote(app_time_zone)})").present?
  end

  # created_at is written in the process's system zone (default_timezone
  # :local). A host is either UTC or runs in the app zone; TZ overrides.
  def self.storage_time_zone
    # Time.now on purpose: the system clock's zone is the one we need, not Time.zone.
    ENV['TZ'].presence || (Time.now.utc_offset.zero? ? 'UTC' : Time.zone.tzinfo.identifier)
  end

  def self.app_time_zone
    Time.zone.tzinfo.identifier # e.g. America/Chicago
  end

  def self.filter_clauses(theater_ids:, seasons:, before_season:, production_ids:, performance_ids:, from_date:,
                          include_external:)
    clauses = []
    binds = {}
    clauses << 'pr.sales_recorded_externally = 0' unless include_external
    {
      theater_ids: ['pr.theater_id IN (:theater_ids)', theater_ids],
      seasons: ['pr.season IN (:seasons)', seasons],
      production_ids: ['pr.id IN (:production_ids)', production_ids],
      performance_ids: ['pf.id IN (:performance_ids)', performance_ids]
    }.each do |key, (clause, values)|
      next if Array(values).empty?

      clauses << clause
      binds[key] = Array(values)
    end
    if before_season
      clauses << 'pr.season < :before_season'
      binds[:before_season] = before_season
    end
    if from_date
      clauses << 'pf.performance_date >= :from_date'
      binds[:from_date] = from_date
    end
    [clauses, binds]
  end

  def self.build_row(hash)
    Row.new(performance_id: hash['performance_id'].to_i, production_id: hash['production_id'].to_i,
            theater_id: hash['theater_id'].to_i, season: hash['season']&.to_i, segment: hash['segment'],
            lead_days: hash['lead_days'].to_i, tickets: hash['tickets'].to_i)
  end

  # sales is the selected orders; the source chain is walked from those alone
  # rather than from every exchanged or split order in the table.
  def self.base_sql
    <<~SQL.squish
      WITH RECURSIVE sales AS (
        SELECT o.id, o.created_at, o.exchange_source_id, o.split_source_id,
               pf.id AS performance_id, pr.id AS production_id, pr.theater_id, pr.season, pf.performance_date
        FROM productions pr
        JOIN performances pf ON pf.production_id = pr.id
        JOIN orders o        ON o.performance_id = pf.id
        WHERE o.type = 'TicketOrder' AND o.status IN (:sold) AND pf.status = :active
          /* filters */
      ),
      chain AS (
        SELECT s.id, COALESCE(s.exchange_source_id, s.split_source_id) AS parent_id, 1 AS depth
        FROM sales s
        WHERE s.exchange_source_id IS NOT NULL OR s.split_source_id IS NOT NULL
        UNION ALL
        SELECT c.id, COALESCE(p.exchange_source_id, p.split_source_id), c.depth + 1
        FROM chain c JOIN orders p ON p.id = c.parent_id
        WHERE (p.exchange_source_id IS NOT NULL OR p.split_source_id IS NOT NULL) AND c.depth < :max_depth
      ),
      roots AS (
        SELECT c.id, c.parent_id AS root_id
        FROM chain c JOIN orders p ON p.id = c.parent_id
        WHERE p.exchange_source_id IS NULL AND p.split_source_id IS NULL
      )
      SELECT s.performance_id, s.production_id, s.theater_id, s.season,
             CASE WHEN EXISTS (
               SELECT 1 FROM payments pay
               JOIN flex_passes fp ON fp.id = pay.flex_pass_id
               JOIN flex_pass_offers fpo ON fpo.id = fp.flex_pass_offer_id
               WHERE pay.order_id = s.id AND pay.type = :pass_type AND pay.number_of_tickets > 0
                 AND (fpo.theater_id IS NOT NULL OR fpo.festival_id IS NOT NULL)
             ) OR EXISTS (
               SELECT 1 FROM payments rpay
               JOIN flex_passes rfp ON rfp.id = rpay.flex_pass_id
               JOIN flex_pass_offers rfpo ON rfpo.id = rfp.flex_pass_offer_id
               WHERE rpay.order_id = r.root_id AND rpay.type = :pass_type AND rpay.number_of_tickets > 0
                 AND (rfpo.theater_id IS NOT NULL OR rfpo.festival_id IS NOT NULL)
             ) THEN 'pass' ELSE 'single' END AS segment,
             GREATEST(DATEDIFF(s.performance_date, DATE(COALESCE(CONVERT_TZ(COALESCE(ro.created_at, s.created_at), :storage_tz, :app_tz),
                                                  COALESCE(ro.created_at, s.created_at)))), 0) AS lead_days,
             SUM(li.ticket_count) AS tickets
      FROM sales s
      JOIN line_items li     ON li.order_id = s.id
      JOIN ticket_classes tc ON tc.id = li.ticket_class_id
      LEFT JOIN roots r      ON r.id = s.id
      LEFT JOIN orders ro    ON ro.id = r.root_id
      WHERE li.type = 'TicketLineItem' AND li.ticket_count > 0
        AND tc.holds_seats = 1 AND tc.complimentary = 0
      GROUP BY s.performance_id, s.production_id, s.theater_id, s.season, segment, lead_days
    SQL
  end

  private_class_method :filter_clauses, :build_row, :base_sql, :storage_time_zone, :app_time_zone
end
