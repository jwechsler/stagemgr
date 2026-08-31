class ResourcedTicketClassDatatable < DatatableBase
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      class_code: { source: 'ResourcedTicketClass.class_code' },
      class_name: { source: 'ResourcedTicketClass.class_name' },
      quantity: { source: 'ResourcedTicketClass.quantity', searchable: false },
      changeover_minutes: { source: 'ResourcedTicketClass.changeover_minutes', searchable: false },
      venues: { searchable: false, orderable: false },
      ticket_price: { source: 'ResourcedTicketClass.ticket_price', searchable: false },
      actions: { searchable: false, orderable: false }
    }
  end

  def data
    records.map do |record|
      {
        id: record.id,
        class_code: record.decorate.class_code,
        class_name: record.decorate.class_name,
        quantity: record.decorate.quantity,
        changeover_minutes: record.decorate.changeover_minutes,
        venues: record.decorate.venue_names,
        ticket_price: record.decorate.ticket_price,
        actions: record.decorate.dt_actions,
        DT_RowID: record.id
      }
    end
  end

  private

  def get_raw_records
    ResourcedTicketClass.all
  end

  def sort_records(records)
    records.order(:class_code)
  end

  # ==== These methods represent the basic operations to perform on records
  # and feel free to override them

  # def filter_records(records)
  # end

  # def paginate_records(records)
  # end

  # ==== Insert 'presenter'-like methods below if necessary
end
