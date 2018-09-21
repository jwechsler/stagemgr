class Admin::PerformancesController < Admin::ApplicationController
  prepend_before_filter :find_production, :except=>[:seating_quickview]
  # append_before_filter :find_performance, :only => [:show, :edit, :update, :destroy, :duplicate]

  load_and_authorize_resource

  # GET /performances
  # GET /performances.xml
  def index
    respond_to do |format|
      format.html # index.html.erb
      format.json {

        params.permit!
        render json: PerformanceDatatable.new(params, view_context: view_context, current_user: current_user, production: @production )
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
    @performance = Performance.new(performance_params)
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
      if @performance.update_attributes(performance_params)
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

  def seating_quickview
    if @performance.production.has_reserved_seating? then
      file_name = @performance.performance_code+'_seating.png'
      file_path=Rails.root.join('public','static','qv',file_name).to_s
      if !File.exist?(file_path) || (File.mtime(file_path) < @performance.seat_assignments.maximum(:updated_at))
        dots = SeatAssignment.joins(:seat).includes(:seat).where(performance_id: @performance.id, status: SeatAssignment::AVAILABLE).pluck(:origin_x, :origin_y, :width)
        result = MiniMagick::Image.open(@performance.seat_map.base_image_map.path)
        image = 'available_seat.png'
        available_dot = MiniMagick::Image.open(Rails.root.to_s + "/app/assets/images/available_seat.png")
        availables = Hash.new
        dots.each { |dot|
          result = result.composite(available_dot.resize("#{dot[2]*2}x#{dot[2]*2}")) do |c|
            c.compose('over')
            c.geometry("+#{dot[0]-dot[2]}+#{dot[1]-dot[2]}")
          end
        }
        result.resize("180x180").write(file_path)
      end
      @qv = '/static/qv/' + file_name
    else
      @qv = ''
    end
    respond_to do |format|
      format.html {
        render 'quickview', layout: false
      }
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

  def performance_params
    params.require(:performance).permit(:performance_date, :production_id, :performance_code, :status,
      :performance_time,  :suppress_notification, :order_url_override,
      :special_feature_display_markdown,
      :special_feature_email_markdown,
      :ticket_class_allocations_attributes=>[:id, :available, :ticket_limit, :shiftable, :shift_to_code,
        :shift_when_capacity_over, :shift_days_before_performance, :ticket_class_id],
      :restricted_payment_type_ids=>[],
      :special_feature_ids=>[])
  end
end
