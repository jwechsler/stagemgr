module OrdersHelper
  def convert_button_label_to_state(button_label)
    case button_label
    when 'Place Order', 'Order tickets', 'Make a donation'
      Order::PROCESSING
    when 'Hold'
      Order::HOLD
    when 'Fulfill'
        Order::FULFILLED
    else
      raise "Don't know what to do with button '#{button_label}'"
    end
  end
  
  def remove_link_unless_new_record(fields)
    out = ''
    out << fields.hidden_field(:_destroy)  unless fields.object.new_record?
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
      render(:partial => options[:partial], :locals => { options[:form_builder_local] => f })
    end
  end

  def generate_template(form_builder, method, options = {})
    escape_javascript generate_html(form_builder, method, options)
  end
  
  private
  def process_order(on_success_redirect_to)
    begin
      @order.save!
      old_status = @order.status
      Order.transaction do
        @order.transition_to!(convert_button_label_to_state(params[:commit]))
        @order.transition_to!(Order::PROCESSED) if @order.status == Order::PROCESSING
      end
    
      respond_to do |format|
        flash[:notice] = "Order was successfully saved and is now #{@order.status_display}"
        format.html { redirect_to(send(on_success_redirect_to,@order.id)) }
      end
    rescue StandardError => e
      @order.status = old_status
      respond_to do |format|
        case e
        when InvalidCreditCard
          flash.now[:notice] = "The credit card you entered was invalid. Reason: #{e.message}"
        when CannotProcessPayment
          flash.now[:notice] = "There was an error while processing your credit card. #{e.message}"
        when ActiveRecord::RecordInvalid
          flash.now[:notice] = "There was an error creating the order. #{e.message}"
        else
          flash.now[:notice] = "There was an error creating the order. #{e.message}"
          logger.error "There was an error creating the order. #{e.message} #{e.backtrace}"
        end
        
        format.html { render 'edit', :layout=>true }
      end
    end
    
  end
  
end
