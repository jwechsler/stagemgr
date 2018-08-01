class AddressesOrdersDatatable < DatatableBase
  def_delegator :@view, :link_to
  def_delegator :@view, :raw
  def_delegator :@view, :number_to_currency
  def_delegator :@view, :order_status_severity_class

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      order: { source: 'Order.id' },
      created: { source: 'Order.created_at' },
      status: { source: 'Order.status' },
    }
  end

  def additional_data
    {
      description: '',
      amount: ''

    }
  end

  def data
    records.map do |order|
      {
        order: raw(link_to(order.id, [:admin, order])),
        created: order.created_at,
        description: order.description,
        amount: number_to_currency(order.total_amount),
        status: raw("<span class=\"label #{order_status_severity_class(order.status)}\">#{order.status}</span>"),
        DT_RowID: order.id,
     }
    end
  end


  def get_raw_records
    result = Order.includes(:payments, performance: :production).where(address_id: address.id)
    result = result.where("productions.theater_id in (:theater_ids)", theater_ids:current_user.theater_ids) if current_user.is_theater_user?
    result
  end

  def address
    @address ||= options[:address]
  end

end
