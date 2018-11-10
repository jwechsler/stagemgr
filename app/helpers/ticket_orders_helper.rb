module TicketOrdersHelper

  def create_ticket_order_for_performance(performance)
    available_ticket_classes = performance.ticket_class_allocations.select { |tca| tca.available }.map { |tca| tca.ticket_class }.select { |tc| tc.web_visible unless tc.nil? }
    order = performance.orders.build(:status=>Order::NEW)
    order.status = Order::NEW
    order.address = Address.new
    available_ticket_classes.each { |tc| order.ticket_line_items.build(:ticket_class=>tc) }
    @order = order
  end

  def preset_line_items_for_display(order)
    tcs = order.ticket_line_items.map { |li| li.ticket_class_id }.uniq
    available = order.performance.ticket_class_allocations.select { |tca| tca.available? && !tcs.include?(tca.ticket_class.id) && tca.ticket_class.web_visible? }.map { |tca| tca.ticket_class }
    available.each { |tc| order.ticket_line_items.build(:ticket_class => tc, :ticket_count => 0) }
    order.ticket_line_items.order(:ticket_class_id)
    order
  end

  def ticket_order_common_params
    common_params + [:production_code, :performance_code, :special_request,
            ticket_line_items_attributes: [:id, :ticket_class, :ticket_class_id, :ticket_class_code, :ticket_count, :_destroy]]
  end
end
