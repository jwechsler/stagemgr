module TicketOrdersHelper

  def ticket_order_params_list
    [:production_code, :performance_code, :special_request,
            ticket_line_items_attributes: [:ticket_class, :ticket_class_id, :ticket_class_code, :ticket_count]]
  end

end
