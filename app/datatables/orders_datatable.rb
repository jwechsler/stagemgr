class OrdersDatatable < DatatableBase
  # The status filter's extra choice: orders flagged for review and not yet
  # resolved (ReviewFlaggable). Read from the review columns alone, so the
  # listing never works out a balance per row.
  NEEDS_REVIEW = 'Needs review'.freeze

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      id: { source: 'Order.id' },
      code: { source: 'Performance.performance_code', cond: filter_by_code },
      name: { source: 'Address.last_first_name', cond: filter_by_name },
      seats: { source: 'Seat.location', cond: filter_by_seats, use_regex: false },
      status: { source: 'Order.status', cond: filter_by_status },
      visits: { searchable: false, orderable: false },
      total: { searchable: false, orderable: false },
      description: { searchable: false, orderable: false },
      order_id: { searchable: false, orderable: false }
    }
  end

  def data
    records.map do |order|
      {
        id: order.decorate.id,
        code: order.decorate.display_code,
        name: order.decorate.address,
        seats: order.decorate.seats,
        status: order.decorate.status,
        visits: order.address.nil? ? 'n/a' : order.address.decorate.orders_processed,
        total: order.decorate.total_paid,
        description: order.decorate.description_with_placed_date,
        order_id: order.id,
        DT_RowId: order.id
      }
    end
  rescue StandardError => e
    Rails.logger.error("Error generating datatable data: #{e.message}")
    [{ error: true, message: 'An error occurred while processing the datatable data. Please refresh the page.' }]
  end

  def filter_by_name
    super_proc = super
    lambda { |column, formatted_value|
      super_proc.call(column, formatted_value)
                .or(::Arel::Nodes::SqlLiteral.new('hold_under').matches("%#{formatted_value}%"))
    }
  end

  private

  # Rows for the page being drawn. The to-one tables the filters and sorts
  # name (addresses, performances) are joined; seats are preloaded in a
  # separate query so they never multiply order rows. The seats filter is a
  # subquery (filter_by_seats), so it needs no join either.
  def get_raw_records
    return order_rows(Order.none) unless current_user.present? && current_user.persisted?

    order_rows(Order.allowed_for(current_user))
  rescue StandardError => e
    Rails.logger.error("error in Orders Datatable query: #{e.message}")
    order_rows(Order.none)
  end

  def order_rows(scope)
    rows = scope.eager_load(:address, performance: :production)
    # A seats sort orders by seats.location, which only a seats join provides.
    sorted_by_seats? ? rows.eager_load(seats: :seat) : rows.preload(seats: :seat)
  end

  def sorted_by_seats?
    datatable.orders.any? { |order| order.column&.column_name == :seats }
  end

  # Deferred join. Sorting the full eager-load (every column of orders,
  # addresses, performances and productions) made MySQL filesort 250k wide
  # rows: 2.7 s for a Name sort. Picking the page's ids from a narrow join
  # lets it walk an index instead (Name: ~1 ms), and only those rows are then
  # loaded. The Seats sort keeps the gem's path: it needs the seats join,
  # which multiplies rows, and is fast enough (~0.9 s).
  def retrieve_records
    return super if sorted_by_seats?

    ids = page_order_ids
    by_id = order_rows(Order.where(id: ids)).index_by(&:id)
    ids.filter_map { |id| by_id[id] }
  end

  def page_order_ids
    ids = narrow_scope.where(build_conditions)
    ids = sort_records(ids).order(Arel.sql(tiebreaker)) if datatable.orderable?
    ids = paginate_records(ids) if datatable.paginate?
    ids.pluck(:id)
  end

  # Joins only the to-one tables the active filters and sorts name: even an
  # inner addresses join turns a 70 ms Code sort into 350 ms. Every order has
  # an address (NOT NULL + foreign key), so that join can be inner; a
  # donation or pass order has no performance, so that one stays LEFT.
  def narrow_scope
    scope = count_scope
    scope = scope.joins(:address) if referenced_columns.include?(:name)
    scope = scope.left_outer_joins(:performance) if referenced_columns.include?(:code)
    scope
  end

  # The name filter (full_name/last_name) and sort need addresses; the code
  # filter and sort need performances. A global search tests every
  # searchable column.
  def referenced_columns
    @referenced_columns ||= begin
      searched = datatable.searchable? ? searchable_columns : search_columns
      sorted = datatable.orders.filter_map(&:column)
      (searched + sorted).map(&:column_name).uniq
    end
  end

  # Makes the page order total, so rows neither repeat nor go missing across
  # pages. A Name sort breaks ties on addresses.id: the name index carries
  # the address id, so MySQL still walks it, whereas orders.id would force a
  # filesort (~150 ms). Orders sharing an address then come in the join's
  # address_owns_orders index order (ascending id).
  def tiebreaker
    primary = datatable.orders.find { |order| order.column&.orderable? }
    direction = primary&.direction || 'ASC'
    column = primary&.column&.column_name == :name ? 'addresses.id' : 'orders.id'
    "#{column} #{direction}"
  end

  # The gem counts by running count(:all) on get_raw_records, which turns
  # the eager-load joins into COUNT(DISTINCT) over every join, twice per
  # draw. Counting needs none of those joins.
  def records_total_count
    @records_total_count ||= count_scope.count
  end

  # No search term: same as the total, so skip the second query. Otherwise
  # join only the to-one tables the filters name (no row multiplication, so
  # no DISTINCT); see narrow_scope.
  def records_filtered_count
    return records_total_count if build_conditions.nil?

    @records_filtered_count ||= narrow_scope.where(build_conditions).count
  end

  def count_scope
    return Order.none unless current_user.present? && current_user.persisted?

    Order.allowed_for(current_user)
  end

  # Matches orders holding any seat whose location contains the term, as a
  # subquery so neither the rows nor the counts join seats. Same
  # case-insensitive substring match as the gem's default :like condition.
  def filter_by_seats
    lambda { |_column, value|
      term = "%#{Order.sanitize_sql_like(value.to_s)}%"
      seat_orders = SeatAssignment.joins(:seat).where(Seat.arel_table[:location].matches(term)).select(:order_uuid)
      Order.arel_table[:uuid].in(seat_orders.arel)
    }
  end

  def filter_by_status
    lambda { |column, value|
      if value == NEEDS_REVIEW
        orders = Order.arel_table
        orders[:review_flagged_at].not_eq(nil).and(orders[:reviewed_at].eq(nil))
      else
        column.table[column.field].matches("%#{value}%")
      end
    }
  end

  def filter_by_code
    lambda { |column, value|
      case value.downcase
      when 'pledge'
        ::Arel::Nodes::SqlLiteral.new('orders.type').eq('DonationPledgeOrder')
      when 'donation'
        ::Arel::Nodes::SqlLiteral.new('orders.type').matches('Donation%Order')
      when 'flexpass'
        ::Arel::Nodes::SqlLiteral.new('orders.type').eq('FlexPassOrder')
      when 'membership', 'member'
        ::Arel::Nodes::SqlLiteral.new('orders.type').eq('MembershipOrder')
      else
        ::Arel::Nodes::SqlLiteral.new('performances.performance_code').matches("%#{column.search.value.upcase}%")
      end
    }
  end

  def current_user
    @current_user ||= options[:current_user]
  end

  def filter_column_condition
    ->(column, _value) { column.table[column.field].eq(column.search.value) }
  end
end
