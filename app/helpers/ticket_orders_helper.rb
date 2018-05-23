module TicketOrdersHelper

  private
  def ticket_order_params
    common_params(:ticket_order).permit(:production_code, :performance_code, :special_request,
      ticket_line_items: [:ticket_class_code, :ticket_count])
  end

end
