module Admin::TicketOrdersHelper
  include ::TicketOrdersHelper

  def order_production_status
    order_production.nil? ? '' : order_production.status
  end
end
