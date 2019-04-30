class Admin::TicketOrdersController < Admin::OrdersController
  load_and_authorize_resource
  include TicketOrdersHelper

  autocomplete :production, :production_code
  autocomplete :ticket_class, :ticket_class_code

  def autocomplete_production_production_code
    production = Production.accessible_by(current_ability).where('(production_code like :code_term or name like :name_term) and status in (:visible_status_list)',
     code_term:"#{params[:term]}%", name_term:"%#{params[:term]}%", visible_status_list:Production.on_sale_statuses,
     )
    render :json => production.map { |prod|
      { id:prod.id,
        label:"#{prod.production_code} - #{prod.name}",
        value:prod.production_code,
        has_reserved_seats: prod.has_reserved_seating? }
    }
  end

  def autocomplete_performance_performance_code
    production = Production.accessible_by(current_ability).find(params[:production_id].to_i) unless params[:production_id].blank?
    if params[:production_id].blank? || production.nil?
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
  end

  def edit
    respond_to do |format|
      if @ticket_order.exchanging?
        format.html { render 'confirm' }
      else
        format.html { render 'edit' }
      end
    end
  end

  def confirm
    respond_to do |format|
      format.html { render 'confirm', :layout=>true}
    end
  end

  def resend_confirmation
    confirmation_task = @ticket_order.tasks.select{|t| t.method_symbol == 'ticket_confirmation'}.first
    unless confirmation_task.nil?
      confirmation_task.retry.run!
      flash[:notice] = 'Confirmation email resent'
    else
      flash[:warning] = 'No customer receipt available for this order'
    end
    respond_to do |format|
      format.html { render 'show', :layout=>true}
    end
  end

  def reprint
    if @ticket_order.fulfilled?
      @ticket_order.send_to_printer
      flash[:notice] = 'Ticket reprinted'
    end
    respond_to do |format|
      format.html { render 'show', :layout=>true}
    end
  end

  def update
    @ticket_order.update_attributes(ticket_order_params)
    if @ticket_order.held? && !(can?(:hold, TicketOrder) || @ticket_order.payment_type.allow_theater_user_holds?)
      flash[:error] = "You don't have permissions to put this order on hold with a payment type of #{@ticket_order.payment_type.display_name}"
      render 'edit'
    else
      # update_ticket_line_items(params[:ticket_order][:ticket_line_items_attributes].values) unless params[:ticket_order][:ticket_line_items_attributes].nil?
      # @ticket_order.payment_type = PaymentType.find(params[:ticket_order][:payment_type_id])
      create_or_update(@ticket_order, params[:commit])
    end
  end

  def create
    @ticket_order.performance=Performance.find_by performance_code:params[:ticket_order][:performance_code]
    @ticket_order.status = Order::NEW if @ticket_order.status.nil?
    time_cutoff = @ticket_order.performance.to_time_with_zone - ($SERVER_CONFIG['minutes_before_performance_close_to_third_party_sales'] || 0).minutes

    if params[:commit].eql?(Order::HOLD) && !(can?(:hold, TicketOrder) || @ticket_order.payment_type.allow_theater_user_holds?)
      flash[:error] = "You don't have permissions to put this order on hold with a payment type of #{@ticket_order.payment_type.display_name}"
      render 'edit'
    else
      unless can?(:order_anytime, TicketOrder) || (Time.now < time_cutoff)
        flash[:error] = "Orders for this performance must be placed through the box office after #{time_cutoff.strftime('%H:%M%p')} on #{time_cutoff.strftime('%m/%d/%y')}"
        render 'edit'
      else
        create_or_update(@ticket_order, params[:commit])
      end
    end
  end

  # def update_ticket_line_items(ticket_lines)
  #   ticket_lines.each {|tli|
  #     c_id = tli['id']
  #     @ticket_order.ticket_line_items.select{|mli| mli.id == c_id.to_i}.each {|mli|
  #       mli.ticket_class_id = tli['ticket_class_id'].to_i unless tli['ticket_class_id'].blank?
  #       mli.ticket_count = tli['ticket_count'].to_i unless tli['ticket_count'].blank?
  #     }
  #   }
  # end

  def set_ticket_classes_for_line_items(order)
    unless params[:ticket_order][:ticket_line_items_attributes].nil?
      params[:ticket_order][:ticket_line_items_attributes].values.each{ |tlia|
        code = tlia[:ticket_class_code]
        found = order.ticket_line_items.select { |tli| tli.id == tlia[:id].to_i}
        found.each {|tli|
          use_class = order.performance.ticket_class_allocations.select {|tca| !tca.ticket_class.nil? && tca.ticket_class.class_code == code && tca.available?}
          tli.ticket_class = use_class.first.ticket_class unless use_class.empty?
        }
      }
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

  protected
  def create_or_update(order, commit_action = nil)

    set_payment_accessors_from_params(order, params[:ticket_order])
    set_ticket_classes_for_line_items(order)

    super(order, commit_action)
  end

  def template_by_order_status(order, commit_action = nil)
    if order.editable? && (!commit_action.nil? && commit_action.downcase.eql?('assign seats') && order.performance.production.has_reserved_seating?)
      'confirm'
    else
      super(order,commit_action)
    end
  end

  private
  def ticket_order_params
    params.require(:ticket_order).permit(*ticket_order_common_params)
  end


end