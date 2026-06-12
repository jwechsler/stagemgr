class FlexPassOrdersDatatable < DatatableBase
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      order: { source: 'Order.id' },
      created: { source: 'Order.created_at' },
      status: { source: 'Order.status' },
      description: { orderable: false },
      amount: { orderable: false }
    }
  end

  def data
    records.map do |order|
      {
        order: order.decorate.id,
        created: order.decorate.created_at,
        description: order.decorate.description,
        amount: order.decorate.total_paid,
        status: order.decorate.status,
        DT_RowID: order.id
      }
    end
  end

  def get_raw_records
    Order.allowed_for(current_user).includes(:payments, performance: :production).references(performance: :production).references(:payments).where(
      'payments.flex_pass_id = :flex_pass_id', flex_pass_id: flex_pass.id
    )
  end

  def flex_pass
    @flex_pass ||= options[:flex_pass]
  end
end
