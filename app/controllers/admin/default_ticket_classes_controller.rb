class Admin::DefaultTicketClassesController < ApplicationController
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
    @default_ticket_class = DefaultTicketClass.new(params[:default_ticket_class])
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
    if @default_ticket_class.update_attributes(params[:default_ticket_class])
      redirect_to [:admin, @default_ticket_class], :notice  => "Successfully updated default ticket class."
    else
      render :action => 'edit'
    end
  end

  def destroy
    @default_ticket_class = DefaultTicketClass.find(params[:id])
    @default_ticket_class.destroy
    redirect_to admin_default_ticket_classes_url, :notice => "Successfully destroyed default ticket class."
  end
end
