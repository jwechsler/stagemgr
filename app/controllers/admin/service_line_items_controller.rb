class Admin::ServiceLineItemsController < Admin::ApplicationController
  def destroy
    @service_line_item = ServiceLineItem.find(params[:id])
    @order = @service_line_item.order
    authorize! :modify_service_items, @order

    unless @service_line_item.amount.to_f.zero? && @service_line_item.facility_fee.to_f > 0
      redirect_to(admin_ticket_order_path(@order),
                  alert: "Only facility-fee-only service items can be deleted this way.") and return
    end

    @service_line_item.destroy
    redirect_to admin_ticket_order_path(@order), notice: "Service fee removed."
  end
end
