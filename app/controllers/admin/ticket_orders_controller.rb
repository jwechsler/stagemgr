require 'http_logger'
class Admin::TicketOrdersController < Admin::OrdersController
  load_and_authorize_resource


  helper TicketOrdersHelper
  helper Admin::TicketOrdersHelper

  autocomplete :production, :production_code
  autocomplete :ticket_class, :ticket_class_code

  def autocomplete_production_production_code
    production = Production.accessible_by(current_ability).where('(production_code like :code_term or name like :name_term) and status in (:visible_status_list)',
     code_term:"#{params[:term]}%", name_term:"%#{params[:term]}%", visible_status_list:Production.on_sale_statuses,
     )
    render :json => production.map { |prod|
      { id:prod.id,
        label:"#{prod.production_code} - #{prod.name}",
        value:prod.production_code }
    }
  end

  def autocomplete_performance_performance_code
    production = Production.accessible_by(current_ability).find_by_production_code(params[:production_code])
    if production.nil?
      render :json=>Array.new
    else
      performances = self.sellable_performances_with_partial_code(production, params[:term])
      render :json => performances.map { |performance|
        {:id=>performance.id, :label=>"#{performance.performance_code} [#{performance.performance_date.to_formatted_s(:show_date)} #{performance.performance_time.to_formatted_s(:hour_min)} (#{performance.number_of_seats_left} remaining)]",
          :value=>performance.performance_code }
      }
    end
  end

  def autocomplete_ticket_line_item_ticket_class_code
    performance = Performance.accessible_by(current_ability).find_by_performance_code(params[:performance_code])
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

  def autocomplete_special_offer_special_offer_code
    performance = Performance.find_by_performance_code(params[:performance_code])
    if performance.nil?
      render :json=>Array.new
    else
      special_offers = SpecialOffer.find_all_by_performance(performance,params[:term],true)
      render :json => special_offers.map { |offer|
        {:id=>offer.id, :value=>offer.code, :label=>"#{offer.code}: #{offer.to_s}"}
      }
    end
  end

  def new
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
    @ticket_order.payment_type = PaymentType.find(params[:ticket_order][:payment_type_id])
    set_ticket_classes_for_line_items
    @ticket_order = process_order(@ticket_order,:edit_admin_order_path)
  end

  def create
    @ticket_order.payment_type = PaymentType.find(params[:ticket_order_params][:payment_type_id]) if @ticket_order.payment_type.nil?
    @ticket_order.performance=Performance.find_by performance_code:params[:ticket_order][:performance_code]
    @ticket_order.status = Order::NEW if @ticket_order.status.nil?

    set_ticket_classes_for_line_items
    time_cutoff = @ticket_order.performance.to_time_with_zone - ($SERVER_CONFIG['minutes_before_performance_close_to_third_party_sales'] || 0).minutes
    if can?(:order_anytime, TicketOrder) || (Time.now < time_cutoff)
      @ticket_order = process_order(@ticket_order,:edit_admin_ticket_order_path)
    else
      flash[:error] = "Orders for this performance must be placed through the box office after #{time_cutoff.strftime('%H:%M%p')} on #{time_cutoff.strftime('%m/%d/%y')}"
      render 'edit', layout: true
    end
  end

  def set_ticket_classes_for_line_items
    params[:ticket_order][:ticket_line_items_attributes].values.each{ |tlia|
      code = tlia[:ticket_class_code]
      found = @ticket_order.ticket_line_items.select { |tli| tli.id == tlia[:id].to_i}
      found.each {|tli|
        use_class = @ticket_order.performance.ticket_class_allocations.select {|tca| tca.ticket_class.class_code == code && tca.available?}

        tli.ticket_class = use_class.first.ticket_class unless use_class.empty?
      }
    }
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

   def sellable_performances_with_partial_code(production, search_term)
    where_clause = "production_id = :production_id and LOWER(performance_code) LIKE :search_term and status in (:sellable_statuses)"
    cannot? :sell_past_performances, TicketOrder do
      where_clause >> ' and performance_date >= curdate()'
    end
    result = Performance.accessible_by(current_ability).where(where_clause,
       production_id:production.id,
       search_term:"%#{search_term.to_s.downcase}%",
       sellable_statuses: Performance.sellable_statuses).order("performance_code ASC")
   end

   private
   def ticket_order_params
    params.require(:ticket_order).permit(*common_params, *common_ticket_order_params)
   end

end