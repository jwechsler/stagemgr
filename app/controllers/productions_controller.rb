class ProductionsController < ApplicationController
  layout $SERVER_CONFIG['ext_site_wrapper']

  prepend_before_action :find_theater, except: %i[index upcoming now_playing box_office by_date show]
  before_action :find_production, only: %i[edit update destroy]

  def by_date
    @start_date = parse_date_param(:start_date, default: Date.today.beginning_of_week)
    @end_date = parse_date_param(:end_date, default: Date.today.beginning_of_week + 1.week - 1)
    @productions = Production.includes(:performances).where(
      'performances.performance_date >= ? and performances.performance_date <= ?',
      @start_date, @end_date
    ).order(performance_date: :asc, performance_time: :asc)
    render :index
  end

  def index
    now_playing
  end

  def upcoming
    @current_date = Date.today.end_of_week + 1
    @productions = Production.opening_after(@current_date).visible.sellable_to_public.order(
      Arel.sql('case theater_id when 1 then 0 else 1 end, productions.first_preview_at')
    )
    render :upcoming
  end

  def now_playing
    @current_date = Date.today.beginning_of_week
    @end_of_week = Date.today.end_of_week
    @second_date = Date.today
    @productions = Production.running_week_of(Date.today).visible.sellable_to_public.order(Arel.sql(
                                                                                             Arel.sql('case theater_id when 1 then 0 else 1 end, productions.name')
                                                                                           ))
    render :now_playing
  end

  def box_office
    @now_playing = now_playing_by_venue(Production::PLAY) + now_playing_by_venue(Production::OFF_TIME) + now_playing_by_venue(Production::SPECIAL_EVENT)
    end_of_week = Date.today.end_of_week
    three_months_from_now = (end_of_week + 2.months).end_of_month
    upcoming_shows = Production.opening_after(end_of_week).visible.order(
      :first_preview_at
    )
    @coming_soon = []
    @long_term = []
    upcoming_shows.each do |prod|
      if prod.first_playing_date <= three_months_from_now
        @coming_soon << prod
      else
        @long_term << prod
      end
    end
  end

  # GET /productions/1
  # GET /productions/1.xml
  def show
    @production = Production.find(params[:id])
    respond_to do |format|
      format.html { render layout: false } # show.html.erb
      format.xml  { render xml: @production }
    end
  end

  # GET /productions/new
  # GET /productions/new.xml
  def new
    @production = @theater.productions.build
    respond_to do |format|
      format.html # new.html.erb
      format.xml { render xml: @production }
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
        format.xml  { render xml: @production, status: :created, location: @production }
      else
        format.html { render action: 'new' }
        format.xml  { render xml: @production.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /productions/1
  # PUT /productions/1.xml
  def update
    respond_to do |format|
      if @production.update(params[:production])
        flash[:notice] = 'Production was successfully updated.'
        format.html { redirect_to(theater_path(@production.theater)) }
        format.xml  { head :ok }
      else
        format.html { render action: 'edit' }
        format.xml  { render xml: @production.errors, status: :unprocessable_entity }
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
    @theater = Theater.find(params[:theater_id])
  end

  def find_production
    @production = @theater.productions.find(params[:id])
  end

  def now_playing_by_venue(production_type)
    now_playing_productions = []
    Venue.all.sort.each do |venue|
      prods = venue.now_playing(production_type)
      now_playing_productions += prods
    end
    now_playing_productions
  end
end
