class Admin::ProductionsController < Admin::ApplicationController
  prepend_before_filter :find_theater
  append_before_filter :find_production, :only => [:show, :edit, :update, :destroy]
  append_before_filter :find_context, :only => [:show]

  # GET /productions/1
  # GET /productions/1.xml
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @production }
    end
  end

  # GET /productions/new
  # GET /productions/new.xml
  def new
    @production = @theater.productions.build
     respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @production }
    end
  end

  def edit; end

  # POST /productions
  # POST /productions.xml
  def create
    @production = Production.new(params[:production])
    @production.theater = @theater

    respond_to do |format|
      if @production.save
        flash[:notice] = 'Production was successfully created.'
        format.html { redirect_to(edit_admin_theater_path(@theater)) }
        format.xml  { render :xml => @production, :status => :created, :location => @production }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @production.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /productions/1
  # PUT /productions/1.xml
  def update
    respond_to do |format|
      if @production.update_attributes(params[:production])
        flash[:notice] = "<i>#{@production.name}</i> was successfully updated."
        format.html { redirect_to(admin_theater_path(@production.theater)) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @production.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /productions/1
  # DELETE /productions/1.xml
  def destroy
    @production.destroy

    respond_to do |format|
      format.html { redirect_to(admin_theater_path(@production.theater)) }
      format.xml  { head :ok }
    end
  end
  
  private
  
  def find_theater
    @theater=Theater.find(params[:theater_id])
  end

  def find_production
    @production = @theater.productions.find(params[:id])
  end
  
end
