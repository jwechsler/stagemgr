module OrdersHelper

  SWIPE_REGEX =/^(%B)([0-9]{16})[\^]([a-zA-Z ]*)(\/)([a-zA-Z ]*)\^([0-9]{2})([0-9]{2})(.*)\?$/

  def convert_button_label_to_state(button_label)
    case button_label
      when 'Checkout', 'Review Order'
        Order::PROCESSING
      when 'Place Order', 'Order Tickets', 'Make a donation', 'Order FlexPass', 'Make a pledge'
        Order::PROCESSED
      when 'Hold'
        Order::HOLD
      when 'Fulfill','Print Tickets'
        Order::FULFILLED
      when 'Update note'
      else
        raise "Don't know what to do with button '#{button_label}'"
    end
  end

  def validate_web_order(order)
    result = true
    begin
      raise "Email required" if order.address.email.blank?
      raise "Name required" if order.address.full_name.blank?
      unless order.payment_type.is_a? PassPaymentType
        raise "Billing address incomplete" if order.address.line1.blank? || order.address.city.blank? || order.address.state.blank? || order.address.zipcode.blank?
        raise "Phone number required" if order.address.phone.blank?
      end
      if order.payment_type.is_a?(CreditCardPaymentType) && !order.credit_card_number.blank?
        raise "Credit card type required" if order.credit_card_type.blank?
        raise "Credit card verification number required" if order.credit_card_verification_number.blank?
      end
    rescue StandardError => e
      result = false
      rescue_error(e)
    end
    result
  end

  private
  def process_order(order, on_success_redirect_to)
    begin
      unless order.credit_card_swipe.blank?
        parsed = order.credit_card_swipe.scan(SWIPE_REGEX)[0]
        order.address.full_name = parsed[4] + ' ' + parsed[2]
        order.credit_card_expiration_year = parsed[5]
        order.credit_card_expiration_month = parsed[6]
        order.credit_card_number = parsed[1]
      end
      order.regularize_credit_card_expiration
      order.save!
      old_status = order.status
      unless (params[:commit].blank? && order.status == Order::PROCESSING)
        on_success_redirect_to = order.transition_to!(convert_button_label_to_state(params[:commit]), on_success_redirect_to)

        if !on_success_redirect_to.nil?
          respond_to do |format|
            if order.status == Order::PROCESSING

              format.html { render "/ticket_orders/confirm", :locals=>{:order=>order} }
            else
              format.html {
                redirect_to send(on_success_redirect_to, order.id), notice:"Order was successfully saved and is now #{order.status_display}"
              }
            end
          end
        end
      else
        respond_to do |format|
          format.html { render 'edit' }
        end
      end
    rescue StandardError => e
      Rails.logger.error(e.message)
      order.status = old_status unless old_status.nil?
      if order.status == Order::PROCESSING && !@order.nil?
        @order.reload
        @order.reload_associated
        @order.attributes.merge!(order.payment_attributes)
      end
      rescue_error(e)
    end

  end


  def rescue_error(e)
    respond_to do |format|
      case e
        when InvalidCreditCard
          flash.now[:error] = "The credit card you entered was invalid. Reason: #{e.message}"
        when CannotProcessPayment
          flash.now[:error] = "There was an error while processing your credit card. #{e.message}"
        when ActiveRecord::RecordInvalid
          flash.now[:error] = "There was an error creating your order. #{e.message}"
          Rails.logger.debug(e)
        else
          flash.now[:error] = "There was a problem with your order. #{e.message}"
          logger.error "There was an error creating the order. #{e.message} #{e.backtrace}"
      end

      format.html { render 'edit', :order=>@order, :layout=>true }
    end
  end

  def payment_types(order, allowed_payment_types = nil, front_end_only = true)
    paytype = payment_types_for(order, front_end_only)
    unless allowed_payment_types.nil?
      paytype = paytype.select {|pt| allowed_payment_types.includes?(paytype)}
    end
    paytype
  end

  def payment_text_for(order)
    case
      when order.payment_type.is_a?(CreditCardPaymentType)
        "This amount will be charged to your #{order.credit_card_type} ending in #{order.credit_card_number[-4..-1]}."
      when order.payment_type.is_a?(MembershipPaymentType)
        "This order will be applied to your membership."
      when order.payment_type.is_a?(FlexPassPaymentType)
        "You are using flex pass #{order.flex_pass_code}."
    end
  end

  def special_feature_footnotes_for(performance, footnotes)
    text = ''
    unless performance.special_features.empty?
      performance.special_features.each do |feature|
        text <<= raw "<sup>[#{@footnotes.find_index(feature.short_name)+1}]&nbsp;</sup>" unless @footnotes.find_index(feature.short_name).nil?
      end
    end
    text <<= raw "<sup>[#{@footnotes.find_index("_custom#{performance.id}")+1}]&nbsp;</sup>" unless @footnotes.find_index("_custom#{performance.id}").nil? || performance.special_feature_display_markdown.blank?
    text
  end

  def create_ticket_order_for_performance(performance)
    available_ticket_classes = performance.ticket_class_allocations.select { |tca| tca.available }.map { |tca| tca.ticket_class }.select { |tc| tc.web_visible unless tc.nil? }
    order = performance.orders.build(:status=>Order::NEW)
    order.status = Order::NEW
    order.address = Address.new
    available_ticket_classes.each { |tc| order.ticket_line_items.build(:ticket_class=>tc) }
    @order = order
  end

end

