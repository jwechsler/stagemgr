class Admin::TicketOrdersController < Admin::OrdersController

  filter_resource_access :additional_collection=>{
    :autocomplete_production_production_code=>:index,
    :autocomplete_performance_performance_code=>:index,
    :autocomplete_ticket_line_item_ticket_class_code=>:index
  }

  autocomplete :production, :production_code, :extra_data => [:production_code], :display_value=>:production_code_autocomplete_display

  def autocomplete_performance_performance_code
    production = Production.with_permissions_to(:read).find_by_production_code(params[:production_code])
    if production.nil?
      render :json=>Array.new
    else
      performances = production.performances.search_by_code(params[:term])
      render :json => performances.map { |performance|
        {:id=>performance.id, :label=>"#{performance.performance_code} [#{performance.performance_date.to_formatted_s(:show_date)} #{performance.performance_time.to_formatted_s(:hour_min)} (#{performance.number_of_seats_left} remaining)]",
          :value=>performance.performance_code }
      }
    end
  end

  def autocomplete_ticket_line_item_ticket_class_code
    performance = Performance.find_by_performance_code(params[:performance_code])
    if performance.nil?
      render :json => Array.new
    else
      ticket_classes = performance.production.ticket_classes.search_by_code_and_performance_id(params[:term], performance.id)
      render :json => ticket_classes.select { |tc| !tc.software_managed }.map { |ticket_class|
        { :id=>ticket_class.id,
          :value=>ticket_class.class_code,
          :label=>"#{ticket_class.class_code} [#{ticket_class.to_s} (#{ticket_class.number_left(performance)} Tickets Left)]",
          :ticket_type=>ticket_class.ticket_type,
          :ticket_price=>ticket_class.ticket_price
        }
      }
    end
  end

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