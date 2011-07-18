class Admin::MembershipOrdersController < Admin::ApplicationController
  filter_resource_access

  def show
    @order = MembershipOrder.find(params[:id])

  end

end