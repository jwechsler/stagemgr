class Admin::TicketOrdersController < Admin::OrdersController

  def show

  end

  def edit

  end

  def redirect_to_proper_action
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