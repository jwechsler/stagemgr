class DonationsController < ApplicationController
  def new
    @order = Order.new
      @order.status = Order::NEW
      @order.address = Address.new
      @order_for_to_s = 'Donation'
      render '/orders/donation', :layout=>'none'

  end

  def confirm
  end

  def show
  end

end
