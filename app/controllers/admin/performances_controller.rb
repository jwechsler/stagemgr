class Admin::PerformancesController < Admin::ApplicationController
  prepend_before_action :find_production, :except => [:seating_quickview]
  # before_action :find_performance, :only => [:show, :edit, :update, :destroy, :duplicate]

  load_and_authorize_resource

  # GET /performances
  # GET /performances.xml
  def index
    respond_to do |format|
      format.html # index.html.erb
      format.json {
        params.permit!
        render json: PerformanceDatatable.new(params, view_context: view_context, current_user: current_user,
                                                      production: @production)
      }
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
    @performance = Performance.new({ :production => @production })
    @performance.populate_ticket_class_allocations
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @performance }
    end
  end

  def duplicate
    old_performance = @performance
    @performance = @performance.dup
    @performance.ticket_class_allocations << old_performance.ticket_class_allocations.map { |tca| tca.dup }
    @performance.save
    render :action => :new
  end

  def release_held_seats
    count = SeatAssignment.release_temporary_holds_for_performance(@performance.id)
    flash[:notice] =
      "Released #{count} held seat#{'s' unless count == 1} for performance #{@performance.performance_code}."
    redirect_to admin_theater_production_performance_path(@performance.production.theater, @performance.production,
                                                          @performance)
  end

  # GET /performances/1/edit
  def edit
    @performance.populate_ticket_class_allocations
  end

  # POST /performances
  # POST /performances.xml
  def create
    @performance = Performance.new(performance_params)
    respond_to do |format|
      if @performance.save
        flash[:notice] = "Performance #{@performance.performance_code} was successfully created."
        format.html {
          redirect_to(admin_theater_production_path(@performance.production.theater, @performance.production))
        }
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
      if @performance.update(performance_params)
        flash[:notice] = "Performance #{@performance.performance_code} was successfully updated."
        format.html { redirect_to([:admin, @performance.production.theater, @performance.production]) }
        format.xml  { head :ok }
      else
        flash.now[:error] = @performance.errors.full_messages[0]
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
      format.html { redirect_to(admin_theater_production_path(production.theater, production)) }
      format.xml  { head :ok }
    end
  end

  def seating_quickview
    @qv = @performance.generate_seating_thumbnail
    respond_to do |format|
      format.html {
        render 'quickview', layout: false
      }
    end
  end

  def email_attendees_form
    authorize! :email_attendees, Performance

    broadcast = PerformanceBroadcast.new(performance: @performance)
    recipient_count = broadcast.recipient_orders.count

    render json: {
      recipient_count: recipient_count,
      performance_code: @performance.performance_code
    }
  end

  def send_broadcast
    authorize! :email_attendees, Performance

    broadcast = @performance.broadcasts.new(
      user: current_user,
      subject: params[:subject],
      from_address: params[:from_address],
      body: params[:body]
    )

    if broadcast.save
      broadcast.queue_broadcast!
      render json: {
        success: true,
        message: "Email queued for #{broadcast.recipient_count} recipients"
      }
    else
      render json: {
        success: false,
        message: broadcast.errors.full_messages.join(', ')
      }, status: :unprocessable_entity
    end
  end

  private

  def find_production
    @theater = Theater.find(params[:theater_id])
    @production = @theater.productions.find(params[:production_id])
  end

  def find_performance
    @performance = @production.performances.find(params[:id])
  end

  def performance_params
    params.require(:performance).permit(:performance_date, :production_id, :performance_code, :status,
                                        :performance_time, :suppress_notification, :withhold_from_public, :order_url_override,
                                        :special_feature_display_markdown,
                                        :special_feature_email_markdown,
                                        :ticket_class_allocations_attributes => [:id, :available, :ticket_limit, :shiftable, :shift_to_code,
                                                                                 :shift_when_capacity_over, :shift_days_before_performance, :ticket_class_id],
                                        :restricted_payment_type_ids => [],
                                        :special_feature_ids => [])
  end
end
