class Admin::TicketOrdersController < Admin::OrdersController

  def new
    @ticket_order = TicketOrder.new
    @ticket_order.address = Address.new
    @ticket_order.ticket_line_items.build
    @ticket_order.status = Order::NEW

    respond_to do |format|
      format.html { render 'edit', :layout=>true }
    end
  end

  def show

    respond_to do |format|
      format.html { if @ticket_order.editable?
                      render 'edit'
                    else
                      render 'show'
                    end
      }
    end
  end

  def edit

  end

  def resend_confirmation
    confirmation_task = @ticket_order.tasks.select{|t| t.method_symbol == 'ticket_confirmation'}.first
    confirmation_task.run!
    flash[:notice] = 'Confirmation email resent'
    respond_to do |format|
      format.html { render 'show', :layout=>true}
    end
  end
  def reprint
    if @ticket_order.fulfilled?
      @ticket_order.send_to_printer
    end
    flash[:notice] = 'Ticket reprinted'
    respond_to do |format|
      format.html { render 'show', :layout=>true}
    end
  end

  def update
    @ticket_order.attributes=params[:ticket_order]
    @ticket_order = process_order(@ticket_order,:edit_admin_order_path)
  end

    def create
      @ticket_order = TicketOrder.new(params[:ticket_order])
      @ticket_order.status = Order::NEW if @ticket_order.status.nil?
      @ticket_order = process_order(@ticket_order,:edit_admin_ticket_order_path)
    end


  def redirect_to_proper_action
    flash.keep
     if @ticket_order.editable?
       if params[:action] != 'edit'
          redirect_to(edit_admin_ticket_order_path(@ticket_order))
       end
     else
       if params[:action] != 'show'
          redirect_to(admin_ticket_order_path(@ticket_order))
       end
     end
   end

end