class MembershipDatatable < DatatableBase
  # Status sorts by business priority, not alphabetically.
  STATUS_PRIORITY_SQL =
    "FIELD(memberships.status, 'Active', 'Suspended', 'Canceled', 'Pending', 'Expired')".freeze
  # Membership start: Stripe subscription start when present, else member_since
  # — same COALESCE the usage reports use.
  START_SQL = 'COALESCE(memberships.start_date, memberships.member_since)'.freeze

  def view_columns
    @view_columns ||= {
      member_code: { source: 'Membership.member_code', cond: :start_with },
      offer: { source: 'MembershipOffer.name' },
      member: { source: 'Address.full_name', cond: filter_by_name },
      status: { source: 'Membership.status' },
      start: { source: 'Membership.member_since', searchable: false },
      membership_end: { source: 'Membership.ended_at', searchable: false },
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
        actions: decorated.dt_actions,
        DT_RowID: record.id
      }
    end
  end

  private

  def get_raw_records
    Membership.accessible_by(current_user.ability)
              .includes(:membership_offer, :address)
              .references(:membership_offer, :address)
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
    end
  end
end
