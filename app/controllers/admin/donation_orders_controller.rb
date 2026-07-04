class Admin::DonationOrdersController < Admin::OrdersController
  load_and_authorize_resource

  def show; end

  def new
    @donation_order.address = Address.new
    @donation_order.donation_line_items.build
    @donation_order.status = Order::NEW

    respond_to do |format|
      format.html { render 'edit' }
    end
  end

  def edit; end

  def create
    create_or_update(@donation_order)
  end

  def update
    @donation_order.update(donation_order_params)
    create_or_update(@donation_order)
  end

  private

  def donation_order_params
    params.require(:donation_order).permit(*donation_order_common_params)
  end
end
