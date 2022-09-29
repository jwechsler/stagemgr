class Admin::ProductionsController < Admin::ApplicationController
  prepend_before_action :find_theater
  before_action :find_context, :only => [:show]
  load_and_authorize_resource

  def index
    respond_to do |format|
      format.json {
        params.permit!
        render json: ProductionDatatable.new(params, view_context: view_context, current_user: current_user, current_theater: @theater )
      }

    end
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

  def edit
  end

  # POST /productions
  # POST /productions.xml
  def create
    if params[:production][:promo].respond_to? :empty?
      params[:production].delete(:promo) if params[:production].has_key?(:promo) && params[:production][:promo].empty?
    end
    @production = Production.new(production_params)
    @production.theater = @theater
    if @production.save
      flash[:notice] = 'Production was successfully created.'
      respond_to do |format|
        format.html { redirect_to(admin_theater_path(@theater)) }
        format.xml  { render :xml => @production, :status => :created, :location => @production }
      end
    else
      respond_to do |format|
        format.html { render :action => "new" }
        format.xml  { render :xml => @production.errors, :status => :unprocessable_entity }
      end
    end
  end


  # PUT /productions/1
  # PUT /productions/1.xml
  def update
    @production.update(production_params)
    respond_to do |format|

      if @production.save
        flash[:notice] =  raw "<i>#{@production.name}</i> was successfully updated."
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


  def production_params
    params.require(:production).permit(:name, :first_preview_at, :press_opening_at, :opening_at,
      :closing_at, :production_code, :production_class, :status, :season, :venue_id, :custom_label,
      :credit_lines, :short_description, :show_description, :running_time, :intermission,
      :allow_late_seating, :capacity, :additional_information_link, :calendar_callout, :conversion_pixel_code,
      :flex_pass_offer_id, :myemma_attendee_group, :survey_link, :mailing_list_link,
      :follow_up_message_2, :confirmation_message, :seat_map_id, :promo, :override_service_items, :override_first_exchange_items,
      :override_addl_exchange_items, :custom1, :custom2)
  end

end
