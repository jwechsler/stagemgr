class Admin::DefaultTicketClassesController < ApplicationController
  authorize_resource
  def index
    @default_ticket_classes = DefaultTicketClass.all
  end

  def show
    @default_ticket_class = DefaultTicketClass.find(params[:id])
  end

  def new
    @default_ticket_class = DefaultTicketClass.new
  end

  def create
    @default_ticket_class = DefaultTicketClass.new(default_ticket_class_params)
    if @default_ticket_class.save
      redirect_to [:admin, @default_ticket_class], :notice => "Successfully created default ticket class."
    else
      render :action => 'new'
    end
  end

  def edit
    @default_ticket_class = DefaultTicketClass.find(params[:id])
  end

  def update
    @default_ticket_class = DefaultTicketClass.find(params[:id])
    if @default_ticket_class.update(default_ticket_class_params)
      redirect_to admin_default_ticket_classes_url,
                  :success => "Successfully updated default ticket class #{@default_ticket_class.class_code}."
    else
      render :action => 'edit'
    end
  end

  def destroy
    @default_ticket_class = DefaultTicketClass.find(params[:id])
    if @default_ticket_class.destroy
      redirect_to admin_default_ticket_classes_url, :notice => "Successfully destroyed default ticket class."
    else
      redirect_to admin_default_ticket_classes_url,
                  :flash => { :error => @default_ticket_class.errors.full_messages.to_sentence }
    end
  end

  private

  def default_ticket_class_params
    params.require(:default_ticket_class).permit(:class_code, :class_name, :minutes_before_show, :ticket_price,
                                                 :ticket_type, :ticketing_fee, :web_visible, :auto_attach, :software_managed, :holds_seats, :purchase_page_annotation,
                                                 :purchase_email_annotation, :suppress_receipt, :hide_pricing, :exchangeable, :royalty_amount)
  end
end
