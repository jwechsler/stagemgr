class Admin::FlexPassOrdersController < Admin::OrdersController
  include OrdersHelper

  #def new
  #  @flex_pass_order = FlexPassOrder.new
  #  @flex_pass_order.address = Address.new
  #  @flex_pass_order.flex_pass_line_items.build
  #  @flex_pass_order.status = Order::NEW
  #
  #  respond_to do |format|
  #    format.html { render 'edit', :layout=>true }
  #  end
  #end

  def show

  end

  def edit
    order = @flex_pass_order
    order
  end

  def update
    @flex_pass_order.attributes=params[:flex_pass_order]
    process_order(@flex_pass_order,:edit_admin_order_path)
  end

    def create
      old_status = Order::NEW
      @flex_pass_order = FlexPassOrder.new(params[:flex_pass_order])
      process_order(@flex_pass_order,:edit_admin_flex_pass_order_path)
    end


  def redirect_to_proper_action
     if @flex_pass_order.editable?
       if params[:action] != 'edit'
          flash.keep
          redirect_to(edit_admin_flex_pass_order_path(@flex_pass_order))
       end
     else
       if params[:action] != 'show'
          flash.keep
          redirect_to(admin_flex_pass_order_path(@flex_pass_order))
       end
     end
   end

   def flex_pass_order_params
     params(:flex_pass_order).permit( *common_params)
   end
end
