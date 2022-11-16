class TicketClassDatatable < DatatableBase
  
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      class_code: { source: 'TicketClass.class_code'},
      class_name: { source: 'TicketClass.class_name'},
      ticket_price: { source: 'TicketClass.ticket_price'},
      ticketing_fee: { source: 'TicketClass.ticketing_fee', :searchable=>false},
      web_visible: { source: 'TicketClass.web_visible', :searchable=>false},
      ticket_type: { source: 'TicketClass.ticket_type'},
      actions: { orderable: false, searchable: false}
    }
  end
  
  def data
    records.map do |ticket_class|
      {
        id: ticket_class.id,
        class_code: ticket_class.decorate.class_code,
        class_name: ticket_class.decorate.class_name,
        ticket_price: ticket_class.decorate.ticket_class,
        ticketing_fee: ticket_class.decorate.ticketing_fee,
        web_visible: ticket_class.decorate.web_visible?,
        ticket_type: ticket_class.decorate.ticket_type,
        actions: ticket_class.decorate.dt_actions,
        DT_RowID: ticket_class.id,
     }
    end
  end

  private

  def get_raw_records
    TicketClass.where(production: production)
  end


  def production
    @production ||= options[:production]
  end

  def theater
    @theater ||= production.theater
  end

  # ==== These methods represent the basic operations to perform on records
  # and feel free to override them

  # def filter_records(records)
  # end

  def sort_records(records)
    records.order(:class_code)
  end

  # def paginate_records(records)
  # end

  # ==== Insert 'presenter'-like methods below if necessary


end
