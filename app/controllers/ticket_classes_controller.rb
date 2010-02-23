class TicketClassesController < ApplicationController
  # GET /ticket_classes
  # GET /ticket_classes.xml
  def index
    @ticket_classes = TicketClass.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @ticket_classes }
    end
  end

  # GET /ticket_classes/1
  # GET /ticket_classes/1.xml
  def show
    @ticket_class = TicketClass.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @ticket_class }
    end
  end

  # GET /ticket_classes/new
  # GET /ticket_classes/new.xml
  def new
    @ticket_class = TicketClass.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @ticket_class }
    end
  end

  # GET /ticket_classes/1/edit
  def edit
    @ticket_class = TicketClass.find(params[:id])
  end

  # POST /ticket_classes
  # POST /ticket_classes.xml
  def create
    @ticket_class = TicketClass.new(params[:ticket_class])

    respond_to do |format|
      if @ticket_class.save
        flash[:notice] = 'TicketClass was successfully created.'
        format.html { redirect_to(@ticket_class) }
        format.xml  { render :xml => @ticket_class, :status => :created, :location => @ticket_class }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @ticket_class.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /ticket_classes/1
  # PUT /ticket_classes/1.xml
  def update
    @ticket_class = TicketClass.find(params[:id])

    respond_to do |format|
      if @ticket_class.update_attributes(params[:ticket_class])
        flash[:notice] = 'TicketClass was successfully updated.'
        format.html { redirect_to(@ticket_class) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @ticket_class.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /ticket_classes/1
  # DELETE /ticket_classes/1.xml
  def destroy
    @ticket_class = TicketClass.find(params[:id])
    @ticket_class.destroy

    respond_to do |format|
      format.html { redirect_to(ticket_classes_url) }
      format.xml  { head :ok }
    end
  end
end
