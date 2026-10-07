class MembershipDatatable < DatatableBase
  # Statuses in business priority: the status sort order and the order of the
  # index page's status filter buttons.
  STATUS_PRIORITY = [
    Membership::ACTIVE, Membership::SUSPENDED, Membership::CANCELED, Membership::PENDING, Membership::EXPIRED
  ].freeze
  STATUS_PRIORITY_SQL = "FIELD(memberships.status, #{STATUS_PRIORITY.map { |status| "'#{status}'" }.join(', ')})".freeze
  # Membership start: Stripe subscription start when present, else member_since
  # — same COALESCE the usage reports use.
  START_SQL = 'COALESCE(memberships.start_date, memberships.member_since)'.freeze
  END_SQL = "CASE WHEN memberships.status = '#{Membership::ACTIVE}' THEN %{today} " \
            'ELSE memberships.ended_at END'.freeze
  # Membership#duration_months in SQL; %{today} is the quoted Date.current, so
  # "today" follows the app's time zone rather than the database's. NULL (no
  # end date) passes through GREATEST as NULL.
  DURATION_SQL = "GREATEST(0, (YEAR(#{END_SQL}) * 12 + MONTH(#{END_SQL})) - " \
                 "(YEAR(#{START_SQL}) * 12 + MONTH(#{START_SQL})) + " \
                 "(DAY(#{END_SQL}) > DAY(#{START_SQL})))".freeze

  def view_columns
    @view_columns ||= {
      member_code: { source: 'Membership.member_code', cond: :start_with },
      offer: { source: 'MembershipOffer.name' },
      member: { source: 'Address.full_name', cond: filter_by_name },
      status: { source: 'Membership.status' },
      start: { source: 'Membership.member_since', searchable: false },
      membership_end: { source: 'Membership.ended_at', searchable: false },
      duration: { source: 'Membership.ended_at', searchable: false }, # sorted by DURATION_SQL
      actions: { searchable: false, orderable: false }
    }
  end

  def data
    records.map do |record|
      decorated = record.decorate
      {
        member_code: decorated.member_code,
        offer: decorated.offer_label,
        member: decorated.member_name,
        status: record.status,
        start: decorated.start_date_display,
        membership_end: decorated.membership_end,
        duration: record.duration_months,
        actions: decorated.dt_actions,
        DT_RowID: record.id
      }
    end
  end

  private

  def get_raw_records
    filter_by_status(
      Membership.accessible_by(current_user.ability)
                .includes(:membership_offer, :address)
                .references(:membership_offer, :address)
    )
  end

  # The index page's status filter; blank or unknown means every status.
  def filter_by_status(scope)
    status = params[:status]
    Membership::RECURRING_STATUSES.include?(status) ? scope.where(status: status) : scope
  end

  # Mirrors the gem's default sort but swaps in custom SQL for the status
  # (priority order) and start (coalesced date) columns; other columns keep
  # their standard column sort.
  def sort_records(records)
    sort_by = datatable.orders.filter_map do |order|
      column = order.column
      next unless column&.orderable?

      order.query(custom_sort_sql(column) || column.sort_query)
    end
    records.order(Arel.sql(sort_by.join(', ')))
  end

  def custom_sort_sql(column)
    case column.data
    when 'status' then STATUS_PRIORITY_SQL
    when 'start' then START_SQL
    when 'duration' then format(DURATION_SQL, today: Membership.connection.quote(Date.current))
    end
  end
end
