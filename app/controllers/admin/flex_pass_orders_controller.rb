class Admin::FlexPassOrdersController < Admin::OrdersController
  load_and_authorize_resource
  before_action :redirect_edits_to_proper_action, :only => [:edit]

  include OrdersHelper
  include FlexPassOrdersHelper

  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json  {
        params.permit!
        render json: FlexPassOrdersDatatable.new(params, view_context: view_context, current_user: current_user, flex_pass: @order.flex_pass)
      }
    end
  end

  def edit
  end

  def update
    @flex_pass_order.update_attributes(flex_pass_order_params)
    create_or_update(@flex_pass_order)
  end

  def create
    create_or_update(@flex_pass_order)
  end

  private

  def flex_pass_order_params
    params.require(:flex_pass_order).permit(*common_flex_pass_order_params)
  end

end
