class Admin::DonationOrdersController < Admin::OrdersController

  def new
    @donation_order = DonationOrder.new
    @donation_order.address = Address.new
    @donation_order.ticket_line_items.build
    @donation_order.status = Order::NEW

    respond_to do |format|
      format.html { render 'edit', :layout=>true }
    end
  end

  def show

  end

  def edit

  end

  def update
    @donation_order.attributes=params[:donation_order]
    process_order(@donation_order,:edit_admin_donation_order_path)
  end

    def create
      old_status = Order::NEW
      @donation_order = DonationOrder.new(params[:ticket_order])
      process_order(@donation_order,:edit_admin_donation_order_path)
    end


  def redirect_to_proper_action
    flash.keep
     if @donation_order.editable?
       if params[:action] != 'edit'
          redirect_to(edit_admin_donation_order_path(@ticket_order))
       end
     else
       if params[:action] != 'show'
          redirect_to(admin_donation_order_path(@ticket_order))
       end
     end
   end

end