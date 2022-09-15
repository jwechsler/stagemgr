class AddressesOrdersDatatable < DatatableBase
  
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      order: { source: 'Order.id' },
      created: { source: 'Order.created_at' },
      status: { source: 'Order.status' },
      description: { searchable: false, orderable: false},
      amount: { searchable: false, orderable: false}
    }
  end

  def data
    unless records.nil?
      records.map do |order|
        {
          order: order.decorate.id ,
          created: order.decorate.created_at,
          description: order.decorate.description,
          amount: order.decorate.total_paid,
          status: order.decorate.status,
          DT_RowID: order.id,
       }
      end
    else
      Array.new
    end
  end


  def get_raw_records
    use_conditions = current_user.ability.model_adapter(Order, :read).conditions.except('type')
    Order.where(use_conditions).where(address_id: address.id)
  end

  def address
    @address ||= options[:address]
  end

end
