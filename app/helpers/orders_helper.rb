module OrdersHelper

  def convert_button_label_to_state(button_label)
    case button_label
      when 'Checkout'
        Order::PROCESSING
      when 'Place Order', 'Order Tickets', 'Make a donation', 'Order FlexPass'
        Order::PROCESSED
      when 'Hold'
        Order::HOLD
      when 'Fulfill'
        Order::FULFILLED
      else
        raise "Don't know what to do with button '#{button_label}'"
    end
  end

  def validate_web_order(order)
    result = true
    begin
      raise "Email required" if order.address.email.blank?
      raise "Name required" if order.address.full_name.blank?
      unless [Order::MEMBERSHIP, Order::FLEX_PASS].include?(order.payment_type)
        raise "Billing address incomplete" if order.address.line1.blank? || order.address.city.blank? || order.address.state.blank? || order.address.zipcode.blank?
        raise "Phone number required" if order.address.phone.blank?
      end
    rescue StandardError => e
      result = false
      rescue_error(e)
    end
    result
  end

  def remove_link_unless_new_record(fields)
    out = ''
    out << fields.hidden_field(:_destroy) unless fields.object.new_record?
    out << link_to("remove", "##{fields.object.class.name.underscore}", :class => 'remove')
    out
  end

# This method demonstrates the use of the :child_index option to render a
# form partial for, for instance, client side addition of new nested
# records.
#
# This specific example creates a link which uses javascript to add a new
# form partial to the DOM.
#
#   <% form_for @project do |project_form| -%>
#     <div id="tasks">
#       <% project_form.fields_for :tasks do |task_form| %>
#         <%= render :partial => 'task', :locals => { :f => task_form } %>
#       <% end %>
#     </div>
#   <% end -%>
  def generate_html(form_builder, method, options = {})
    options[:object] ||= form_builder.object.class.reflect_on_association(method).klass.new
    options[:partial] ||= "#{method.to_s.singularize}_form"
    options[:form_builder_local] ||= :f

    form_builder.fields_for(method, options[:object], :child_index => 'NEW_RECORD') do |f|
      render(:partial => options[:partial], :locals => {options[:form_builder_local] => f})
    end
  end

  def generate_template(form_builder, method, options = {})
    escape_javascript generate_html(form_builder, method, options)
  end

  private
  def process_order(order, on_success_redirect_to)
    begin
      order.credit_card_expiration_year = "20" + order.credit_card_expiration_year unless order.credit_card_expiration_year.blank? || order.credit_card_expiration_year.length > 2
      order.save!
      old_status = order.status
      Order.transaction do
        on_success_redirect_to = order.transition_to!(convert_button_label_to_state(params[:commit]), on_success_redirect_to)
        # @order.transition_to!(Order::PROCESSED) if @order.status == Order::PROCESSING
      end

      if !on_success_redirect_to.nil?
        respond_to do |format|
          flash[:notice] = "Order was successfully saved and is now #{order.status_display}"
          format.html { redirect_to(send(on_success_redirect_to, order.id)) }
        end
      end
    rescue StandardError => e
      order.status = old_status
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
        else
          flash.now[:error] = "There was a problem with your order. #{e.message}"
          logger.error "There was an error creating the order. #{e.message} #{e.backtrace}"
      end

      format.html { render 'edit', :layout=>true }
    end
  end

  def submit_recurring_payment_request
    gateway ||= ActiveMerchant::Billing::PaypalRecurringGateway.new(
        :login => $PAYPAL_LOGIN,
        :password => $PAYPAL_PASSWORD)
    membership_offer = @order.membership_offer

    setup_response = gateway.setup_authorization((membership_offer.recurring_cost * 100).to_i,
                                                 :ip => request.remote_ip,
                                                 :return_url => url_for(confirm_membership_order_path(:only_path=>false)),
                                                 :cancel_return_url => "http://www.theaterwit.org/",
                                                 :description => "Test description!"
    )

    redirect_to gateway.redirect_url_for(setup_response.token)
  end

end

