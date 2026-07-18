# TRG-format export of every address whose first-EVER attendance falls on or
# after a given start date (and no later than today).
#
# "First attendance" is the MIN(performance_date) over ALL attended orders
# (status PROCESSED/FULFILLED, performance already past) — comp, membership,
# and flex-pass visits included. So :FirstAttendedDate may legitimately be a
# comp visit; that is by design. To appear in the export at all, the patron
# must additionally have at least one *qualifying* order: a FULFILLED order
# that contains a non-comp ticket and was NOT paid with a flex pass and NOT
# paid with a standard ('production') membership. Timed-membership
# attendances qualify. Merely PROCESSED orders still establish attendance
# (and can disqualify or date a patron) but never make one eligible.
#
# Known limitations:
# - Exchange chains count only the exchange-target order (the original is
#   EXCHANGED, which is not an attending status), so a patron whose first
#   visit was later exchanged is dated by the order they actually attended.
# - Addresses merged away as duplicates can make a long-time patron look
#   like a first-timer (history under the old address_id is not followed).
class FirstTimeAttendeeReport < MailingList
  # TRG list-type code for the :Segment column: these patrons are treated as
  # single-ticket buyers.
  TRG_SEGMENT_CODE = 'STB'.freeze

  BATCH_SIZE = 1000

  # Phase A: one grouped scan over attended orders. The INNER JOIN on
  # performances naturally drops donation/pass orders (no performance_id).
  # The HAVING clause keeps only addresses whose first-ever attendance is on
  # or after :start_date AND who have at least one qualifying FULFILLED order.
  # payments.type is pinned as a string literal on purpose: Payment STI
  # subclass scopes match ALL payment types project-wide, so subclass
  # constants are never used to build these predicates.
  CANDIDATES_SQL = <<~SQL.squish.freeze
    SELECT o.address_id, MIN(p.performance_date) AS first_attended_date
    FROM orders o
    INNER JOIN performances p ON p.id = o.performance_id
    INNER JOIN addresses a    ON a.id = o.address_id
    WHERE o.status IN (:attended_statuses)
      AND p.performance_date <= :today
      AND COALESCE(a.placeholder, 0) = 0
      AND (COALESCE(a.line1, '') <> '' OR COALESCE(a.email, '') <> '')
    GROUP BY o.address_id
    HAVING MIN(p.performance_date) >= :start_date
       AND MAX(CASE WHEN
             o.status = :fulfilled
             AND EXISTS (SELECT 1 FROM line_items li
                     JOIN ticket_classes tc ON tc.id = li.ticket_class_id
                     WHERE li.order_id = o.id AND tc.complimentary = 0)
             AND NOT EXISTS (SELECT 1 FROM payments fp
                     WHERE fp.order_id = o.id AND fp.type = 'FlexPassPayment')
             AND NOT EXISTS (SELECT 1 FROM payments mp
                     JOIN memberships m        ON m.id = mp.membership_id
                     JOIN membership_offers mo ON mo.id = m.membership_offer_id
                     WHERE mp.order_id = o.id AND mp.type = 'MembershipPayment'
                       AND mo.membership_type = 'production')
           THEN 1 ELSE 0 END) = 1
  SQL

  # Phase B: theater of the first attendance, per candidate address.
  # ROW_NUMBER ordered by (performance_date, order id) makes same-date ties
  # deterministic. LEFT JOINs so an orphaned performance yields a blank
  # theater name instead of dropping the patron.
  FIRST_THEATER_SQL = <<~SQL.squish.freeze
    SELECT address_id, theater_name FROM (
      SELECT o.address_id,
             t.name AS theater_name,
             ROW_NUMBER() OVER (PARTITION BY o.address_id
                                ORDER BY p.performance_date ASC, o.id ASC) AS rn
      FROM orders o
      INNER JOIN performances p ON p.id = o.performance_id
      LEFT JOIN productions pr ON pr.id = p.production_id
      LEFT JOIN theaters t     ON t.id = pr.theater_id
      WHERE o.address_id IN (:address_ids)
        AND o.status IN (:attended_statuses)
        AND p.performance_date <= :today
    ) ranked
    WHERE rn = 1
  SQL

  attr_reader :start_date

  def initialize(start_date, reporting_user_id = nil, theater_ids: [])
    super(reporting_user_id, theater_ids: theater_ids)
    @start_date = start_date.to_date
    self.headers = TRG_IMPORT_HEADERS + %i[FirstAttendedDate FirstAttendedTheatre]
    # :Segment auto-emits the data-hash key at CSV time (Report#save_report_as_csv);
    # per-row hashes never set :Segment themselves.
    @data = { TRG_SEGMENT_CODE => [] }
  end

  # TRG :Title carries the descriptive segment label (not a salutation). Year
  # is intentionally omitted; :Season carries it.
  def segment_title
    "First Time Attendee as of #{start_date.strftime('%m/%d')}"
  end

  def create
    first_dates = first_attendance_dates
    first_dates.keys.each_slice(BATCH_SIZE) do |batch|
      theater_names = first_attended_theater_names(batch)
      addresses = Address.where(id: batch).index_by(&:id)
      batch.each do |address_id|
        address = addresses[address_id]
        next if address.nil?

        hash = mailing_hash_from_buyer(address, true)
        hash[:Title] = segment_title
        hash[:Season] = start_date.year
        hash[:FirstAttendedDate] = first_dates[address_id]
        hash[:FirstAttendedTheatre] = theater_names[address_id]
        @data[TRG_SEGMENT_CODE] << hash
      end
    end

    file_name = report_filename(File.join(Dir.tmpdir, "first_time_attendees_#{reporting_user_id}.csv"))
    save_report_to_filestore(file_name, "First time attendees since #{start_date}")
  end

  private

  # Phase A. Returns { address_id => first_attended_date } for every
  # qualifying candidate address.
  def first_attendance_dates
    sql = ActiveRecord::Base.sanitize_sql_array(
      [CANDIDATES_SQL, { attended_statuses: Order::ATTENDING_STATUSES,
                         fulfilled: Order::FULFILLED,
                         today: Date.current,
                         start_date: start_date }]
    )
    ActiveRecord::Base.connection.select_all(sql).to_h do |row|
      [row['address_id'], row['first_attended_date']]
    end
  end

  # Phase B. Returns { address_id => theater name of first attendance } for
  # one batch of candidate address ids.
  def first_attended_theater_names(address_ids)
    sql = ActiveRecord::Base.sanitize_sql_array(
      [FIRST_THEATER_SQL, { address_ids: address_ids,
                            attended_statuses: Order::ATTENDING_STATUSES,
                            today: Date.current }]
    )
    ActiveRecord::Base.connection.select_all(sql).to_h do |row|
      [row['address_id'], row['theater_name']]
    end
  end
end
