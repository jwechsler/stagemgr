class MembershipOrdersController < ApplicationController
  layout 'none'
  include OrdersHelper

  def create
    @order = MembershipOrder.new(params[:membership_order])
    process_order(:edit_membership_order_path)
  end

  def show
  end

  def edit
  end

  def confirm
  end

  def checkout
  end

  protected

end
