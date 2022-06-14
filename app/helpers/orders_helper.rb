module OrdersHelper

  SWIPE_REGEX =/^(%B)([0-9]{16})[\^]([a-zA-Z ]*)(\/)([a-zA-Z ]*)\^([0-9]{2})([0-9]{2})(.*)\?$/


  def convert_button_label_to_state(button_label)
    case button_label.downcase
      when 'checkout', 'review order', 'assign seats'
        Order::PROCESSING
      when 'place order', 'order tickets', 'make a donation', 'order flexpass', 'make a pledge'
        Order::PROCESSED
      when 'hold'
        Order::HOLD
      when 'fulfill','print tickets'
        Order::FULFILLED
      when 'update note'
      else
        raise "Don't know what to do with button '#{button_label}'"
    end
  end

  def validate_web_order(order)
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
    rescue RuntimeError => e
      result = false
      rescue_error(e)
      return false
    end
    result = true
    unless order.errors.empty?
      flash[:error] = order.errors.full_messages.first
      result = false
    end
    return result
  end

  def update_order_notes_from_params(order, order_params)
    order.hold_under=order_params[order.class.name.underscore.to_sym][:hold_under]
    order.notes=order_params[:notes]
  end

  public
  def common_params
    [ :special_offer_code, :hold_under, :payment_type_id, :credit_card_type, :additional_donation,
      :credit_card_number, :credit_card_expiration_month, :credit_card_expiration_year,
      :credit_card_verification_number, :credit_card_swipe, :credit_card_confirmation_code,
      :flex_pass_code, :member_code, :check_number, :add_to_email_list, :marketing_source, :notes, :status,
      address_attributes: [:full_name, :email, :phone, :line1, :line2, :city, :state, :zipcode],
      service_line_items_attributes: [:id, :description, :facility_fee, :amount, :_destroy, :suppress_for_pass_payments]
    ]
  end

  def set_payment_accessors_from_params(order, order_params)
    order.special_offer_code = order_params[:special_offer_code]
    order.additional_donation = order_params[:additional_donation]
    order.credit_card_number = order_params[:credit_card_number]
    order.credit_card_type = order_params[:credit_card_type]
    order.credit_card_expiration_year = order_params[:credit_card_expiration_year]
    order.credit_card_expiration_month = order_params[:credit_card_expiration_month]
    order.credit_card_verification_number = order_params[:credit_card_verification_number]
    order.credit_card_confirmation_code = order_params[:credit_card_confirmation_code]
    order.credit_card_swipe = order_params[:credit_card_swipe]
    order.flex_pass_code = order_params[:flex_pass_code]
    order.member_code = order_params[:member_code]
    order.check_number = order_params[:check_number]
  end

  # prep order for status change.
  # Returns true if order converted with no errors, false if processing interrupted
  # Params:
  # @order           [Order]  Order object to alter
  # @change_to_state [String] Transition state as defined in order.rb (Order::PROCESSING, etc)
  #
  # @return true if state change succeeded, false if not.  errors are stored in order object
  def process_order(order, change_to_state)
    Rails.logger.info("Transitioning order #{order.id.nil? ? '(new)' : order.id} to #{change_to_state}")
    begin
      unless order.credit_card_swipe.blank?
        parsed = order.credit_card_swipe.scan(SWIPE_REGEX)[0]
        order.address.full_name = parsed[4] + ' ' + parsed[2]
        order.credit_card_expiration_year = parsed[5]
        order.credit_card_expiration_month = parsed[6]
        order.credit_card_number = parsed[1]
      end
      order.regularize_credit_card_expiration
      order.transition_to!(change_to_state)

    rescue StandardError => e
      if order.errors.empty?
        rescue_error(e)
      else
        flash[:error] = order.errors.full_messages.first
      end
      return false
    end

    flash[:notice] = "Order was successfully #{order.status_display.downcase}" if order.finalized?
    return true

  end

  def rescue_error(e)
    case e
      when InvalidCreditCard
        flash[:error] = "The credit card you entered was invalid. Reason: #{e.message}"
      when CannotProcessPayment
        flash[:error] = "There was an error while processing your credit card. #{e.message}"
      when ActiveRecord::RecordInvalid
        flash[:error] = "There was an error creating your order. #{e.message}"
      else
        flash[:error] = e.message
        Rails.logger.error "There was an error creating order. #{e.message}"
        Rails.logger.debug e.backtrace.join("\n")
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

end

