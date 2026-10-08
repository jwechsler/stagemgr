class CurrentUser::ProductionsController < CurrentUser::ApplicationController
  prepend_before_action :find_theater
  before_action :find_production, only: %i[show]

  # GET /productions/1
  # GET /productions/1.xml
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render xml: @production }
    end
  end

  # GET /productions/new
  # GET /productions/new.xml
  def new
    @production = @theater.productions.build
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render xml: @production }
    end
  end

  # POST /productions
  # POST /productions.xml
  def create
    @production = Production.new(params[:production])
    @production.theater = @theater

    respond_to do |format|
      if @production.save
        flash[:notice] = 'Production was successfully created.'
        format.html { redirect_to(edit_theater_path(@theater)) }
        format.xml  { render xml: @production, status: :created, location: @production }
      else
        format.html { render action: 'new' }
        format.xml  { render xml: @production.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def find_theater
    @theater = Theater.find(params[:theater_id])
  end

  def find_production
    @production = @theater.productions.find(params[:id])
  end
end
