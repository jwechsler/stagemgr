#class DonationsController < ApplicationController
#  layout 'ext_site_wrapper'

#  def new
#    @order = DonationOrder.new
#    @order.status = Order::NEW
#    @order.address = Address.new
#    @order.donation_line_items.build(:donation_amount=>0)
#    # @todo Replace donation levels with user controlled donation level code
#    @levels = ActiveSupport::OrderedHash.new
#    @levels["Buddy ($100)"] = 100
#    @levels["Fast Friend ($250)"] = 250
#    @levels["Comrade ($500)"] = 500
#    @levels["Confidante ($1500)"] = 1500
#    @levels["Patron ($2500)"] = 2500
#    respond_to do |format|
#      format.html{ render '/donation_orders/edit', :layout=>'ext_site_wrapper' }
#    end
#  end
#
#  def confirm
#  end
#
#  def show
#  end
#
#  def create
#    @order = DonationOrder.new(params[:order])
#  end
#
#end
