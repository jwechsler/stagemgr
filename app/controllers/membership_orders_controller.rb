class MembershipOrdersController < ApplicationController
  layout 'none'

  def new
    @order = MembershipOrder.new
    @order.address = Address.new
    render :action=>'edit'
  end

  def create
    @order = MembershipOrder.new(params[:order])

  end

  def show
  end

  def edit
  end

  def confirm
  end

  def checkout
  end

end
