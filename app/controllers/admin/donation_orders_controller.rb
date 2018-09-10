class Admin::DonationOrdersController < Admin::OrdersController
  load_and_authorize_resource

  def new

    @donation_order.address = Address.new
    @donation_order.donation_line_items.build
    @donation_order.status = Order::NEW

    respond_to do |format|
      format.html { render 'edit' }
    end
  end

  def show
  end

  def edit
  end

  def update
    @donation_order.update_attributes(donation_order_params)
    create_or_update(@donation_order)
  end

  def create
    create_or_update(@donation_order)
  end

  protected
  def redirect_to_proper_action
   flash.keep
    if @donation_order.editable?
      if params[:action] != 'edit'
         redirect_to(edit_admin_donation_order_path(@donation_order))
      end
    else
      if params[:action] != 'show'
         redirect_to(admin_donation_order_path(@donation_order))
      end
    end
  end

  def create_or_update(order)
    new_state = convert_button_label_to_state(params[:commit])
    if action.new_state.blank? then
      simple_save(order)
    else
      process_order(order,new_state) # Either way the process goes, we pick the display by current status
      respond_to do |format|
        format.html { render template_by_order_status(@donation_order) }
      end
    end
  end

  def simple_save(order)
    order.save
    respond_to do |format|
      format.html { render template_by_order_status(order) }
    end
  end

  def template_by_order_status(order)
    if order.editable?
      'edit'
    else
      'show'
    end
  end

  private
  def donation_order_params
   params.require(:donation_order).permit(*donation_order_common_params)
  end
end