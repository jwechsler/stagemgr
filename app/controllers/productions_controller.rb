class ProductionsController < ApplicationController
  prepend_before_filter :find_theater, :except => [:index, :upcoming, :now_playing]
  append_before_filter :find_production, :only => [:show, :edit, :update, :destroy]
  
  def by_date
    @start_date = params[:start_date].nil? ? Date.today.beginning_of_week : Date.parse(params[:start_date])
    @end_date = params[:end_date].nil? ? Date.today.beginning_of_week + 1.week - 1 : Date.parse(params[:end_date])
    @productions = Production.find(:all, :include=>[:performances], :conditions=>['performances.performance_date >= ? and performances.performance_date <= ?',@start_date,@end_date], :order=>'performances.performance_date, performances.performance_time asc')
    render :index, :layout=>false
  end
    
  def index
    @current_date = Date.today
    @b_week = Date.today.beginning_of_week
    @e_week = Date.today.end_of_week
    @productions = Production.find(:all, :conditions=>['productions.closing_at > ? and productions.status = \'Active\'',@b_week], :order=>'case when date(productions.first_preview_at) >= date(current_date) then 1 else 0 end, case theater_id when 1 then 0 else 1 end, case when date(productions.first_preview_at) >= date(current_date) then productions.first_preview_at else productions.name end')
    render :upcoming, :layout=>false
  end
  
  def upcoming
    @current_date = Date.today.end_of_week + 1
    @productions = Production.find(:all, :conditions=>['productions.first_preview_at > ? and productions.status = \'Active\'',@current_date], :order=>'case theater_id when 1 then 0 else 1 end, productions.first_preview_at')
    render :upcoming, :layout=>false
  end
  
  def now_playing
    @current_date = Date.today.beginning_of_week
    @end_of_week = Date.today.end_of_week
    @second_date = Date.today
    @productions = Production.find(:all, :conditions=>['productions.first_preview_at <= ? and productions.closing_at > ? and productions.status = \'Active\'',@end_of_week,@second_date], :order=>'case theater_id when 1 then 0 else 1 end, productions.name')
    render :now_playing, :layout=>false
  end
  

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
        format.html { redirect_to(theater_path(@theater)) }
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
        flash[:notice] = 'Production was successfully updated.'
        format.html { redirect_to(theater_path(@production.theater)) }
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
      format.html { redirect_to(theater_path(@production.theater)) }
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
