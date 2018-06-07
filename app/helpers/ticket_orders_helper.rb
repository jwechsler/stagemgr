module TicketOrdersHelper

  def common_ticket_order_params
    [:production_code, :performance_code, :special_request,
        ticket_line_items_attributes: [:ticket_class, :ticket_class_id, :ticket_class_code, :ticket_count]]
  end

end
