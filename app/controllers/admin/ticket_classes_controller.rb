class Admin::TicketClassesController < ApplicationController
  prepend_before_filter :find_production
  append_before_filter :find_ticket_class, :only => [:edit, :update, :destroy]

  def index
    @ticket_classes = @production.ticket_classes.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @ticket_classes }
    end
  end

  def new
    @ticket_class = @production.ticket_classes.build

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  def edit; end

  def create
    @ticket_class = TicketClass.new(params[:ticket_class])

    respond_to do |format|
      if @ticket_class.save
        flash[:notice] = 'TicketClass was successfully created.'
        format.html { redirect_to(admin_theater_production_ticket_classes_path(@theater,@production)) }
        format.xml  { render :xml => @ticket_class, :status => :created, :location => @ticket_class }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @ticket_class.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @ticket_class.update_attributes(params[:ticket_class])
        flash[:notice] = 'TicketClass was successfully updated.'
        format.html { redirect_to(admin_theater_production_ticket_classes_path(@theater,@production)) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @ticket_class.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @ticket_class.destroy

    respond_to do |format|
      format.html { redirect_to(admin_theater_production_ticket_classes_path(@theater,@production)) }
      format.xml  { head :ok }
    end
  end
  
  private
  
  def find_production
    @theater=Theater.find(params[:theater_id])
    @production = @theater.productions.find(params[:production_id])
  end

  def find_ticket_class
    @ticket_class = @production.ticket_classes.find(params[:id])
  end
  
end
