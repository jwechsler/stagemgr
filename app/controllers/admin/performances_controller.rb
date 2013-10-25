class Admin::PerformancesController < Admin::ApplicationController
  prepend_before_filter :find_production
  append_before_filter :find_performance, :only => [:show, :edit, :update, :destroy, :duplicate]

  # GET /performances
  # GET /performances.xml
  def index
    @performances = @production.performances

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @performances }
    end
  end

  # GET /performances/1
  # GET /performances/1.xml
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @performance }
    end
  end

  # GET /performances/new
  # GET /performances/new.xml
  def new
    @performance = Performance.new({:production=>@production})
    @performance.populate_ticket_class_allocations
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @performance }
    end
  end

  def duplicate
    old_performance = @performance
    @performance = @performance.dup
    @performance.ticket_class_allocations <<  old_performance.ticket_class_allocations.map{|tca|tca.dup}
    @performance.save
    render :action => :new
  end

  # GET /performances/1/edit
  def edit
    @performance.populate_ticket_class_allocations
  end

  # POST /performances
  # POST /performances.xml
  def create
    @performance = Performance.new(params[:performance])
    respond_to do |format|
      if @performance.save
        flash[:notice] = "Performance #{@performance.performance_code} was successfully created."
        format.html { redirect_to(admin_theater_production_path(@performance.production.theater, @performance.production)) }
        format.xml  { render :xml => @performance, :status => :created, :location => @performance }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @performance.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /performances/1
  # PUT /performances/1.xml
  def update
    respond_to do |format|
      if @performance.update_attributes(params[:performance])
        flash[:notice] = "Performance #{@performance.performance_code} was successfully updated."
        format.html { redirect_to([:admin,@performance.production.theater,@performance.production]) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @performance.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /performances/1
  # DELETE /performances/1.xml
  def destroy
    production = @performance.production
    @performance.destroy

    respond_to do |format|
      format.html { redirect_to(admin_theater_production_path(production.theater,production)) }
      format.xml  { head :ok }
    end
  end

  private

  def find_production
    @theater=Theater.find(params[:theater_id])
    @production = @theater.productions.find(params[:production_id])
  end

  def find_performance
    @performance = @production.performances.find(params[:id])
  end

end
