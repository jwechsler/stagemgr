module OrdersHelper

  SWIPE_REGEX =/^(%B)([0-9]{16})[\^]([a-zA-Z ]*)(\/)([a-zA-Z ]*)\^([0-9]{2})([0-9]{2})(.*)\?$/

  def convert_button_label_to_state(button_label)
    case button_label
      when 'Checkout', 'Review Order'
        Order::PROCESSING
      when 'Place Order', 'Order Tickets', 'Make a donation', 'Order FlexPass'
        Order::PROCESSED
      when 'Hold'
        Order::HOLD
      when 'Fulfill','Print Tickets'
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


  def fix_expiration_year(expiration_year)
    unless expiration_year.blank? || expiration_year.length > 2
      expiration_year = "20" + expiration_year
    end
    expiration_year
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
      order.credit_card_expiration_year = self.fix_expiration_year(order.credit_card_expiration_year)
      unless order.credit_card_expiration_year.blank? || order.credit_card_expiration_year.length > 2
        order.credit_card_expiration_year = "20" + order.credit_card_expiration_year

      end
      order.save!
      old_status = order.status
      unless (params[:commit].blank? && order.status == Order::PROCESSING)
        on_success_redirect_to = order.transition_to!(convert_button_label_to_state(params[:commit]), on_success_redirect_to)

        if !on_success_redirect_to.nil?
          respond_to do |format|
            if order.status == Order::PROCESSING

              format.html { render "/ticket_orders/confirm", :locals=>{:order=>order} }
            else
              flash[:notice] = "Order was successfully saved and is now #{order.status_display}"
              format.html { redirect_to(send(on_success_redirect_to, order.id)) }
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
      if order.status == Order::PROCESSING
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
        else
          flash.now[:error] = "There was a problem with your order. #{e.message}"
          logger.error "There was an error creating the order. #{e.message} #{e.backtrace}"
      end

      format.html { render 'edit', :order=>@order, :layout=>true }
    end
  end

end

