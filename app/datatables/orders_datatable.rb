class OrdersDatatable < DatatableBase
  
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      id: { source: 'Order.id' },
      code: { source: 'Performance.performance_code', cond: filter_by_code },
      name: { source: 'Address.last_first_name' },
      seats: { source: 'Seat.location'},
      status: { source: 'Order.status' },
      code: { searchable: false, orderable: false},
      name: { searchable: false, orderable: false},
      visits: { searchable: false, orderable: false},
      total: { searchable: false, orderable: false},
      description: { searchable: false, orderable: false},
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
        visits: order.address.nil? ? "n/a" : (current_user.is_theater_user? ? order.address.orders_processed(@current_user.theater_ids) : order.address.orders_processed ),
        total: order.decorate.total_paid,
        description: order.decorate.description,
        DT_RowID: order.id
     }
    end
  end

#
private

  def get_raw_records
    use_conditions = current_user.ability.model_adapter(Order, :read).conditions.except('type')
    Order.where(use_conditions)
  end

  def sort_records(records)
    records.order(id: :desc)
  end

  def filter_by_code
    ->(column, formatted_value) { case formatted_value.downcase
                  when 'pledge'
                    ::Arel::Nodes::SqlLiteral.new('orders.type').eq('DonationPledgeOrder')
                  when 'donation'
                    ::Arel::Nodes::SqlLiteral.new('orders.type').matches('Donation%Order')
                  when 'flexpass'
                    ::Arel::Nodes::SqlLiteral.new('orders.type').eq('FlexPassOrder')
                  when 'membership', 'member'
                    ::Arel::Nodes::SqlLiteral.new('orders.type').eq('MembershipOrder')
                  else
                    ::Arel::Nodes::SqlLiteral.new('performances.performance_code').matches("%#{formatted_value.upcase}%")
                  end
                }
  end

  def current_user
    @current_user ||= options[:current_user]
  end


  def filter_column_condition
    ->(column) { column.table[column.field].eq(column.search.value) }
  end

end