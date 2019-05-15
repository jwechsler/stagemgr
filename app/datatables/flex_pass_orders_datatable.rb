class FlexPassOrdersDatatable < DatatableBase
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
    result = Order.accessible_by(current_user.ability,:read).includes(:payments, performance: :production).references(performance: :production).references(:payments).where("payments.flex_pass_id = :flex_pass_id", :flex_pass_id=>flex_pass.id)
    result
  end

  def flex_pass
    @flex_pass ||= options[:flex_pass]
  end

end
