class Admin::TheatersController < Admin::ApplicationController
  before_filter :remove_empty_logo
  load_and_authorize_resource

  before_filter :find_context, :only=>:show
  def index
    @theaters = @theaters.sort_by{|t| [t.status, t.theater_class, t.name]}

    if current_user.is_theater_user?
      @theaters = @theaters.select{|t| current_user.theaters.include?(t)}
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json {
        params.permit!
        render json: TheaterDatatable.new(params, view_context: view_context, current_user: current_user )
      }
    end
  end

  # GET /theaters/new
  # GET /theaters/new.xml
  def new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @theater }
    end
  end

  def show
  end

  def edit
  end

  # POST /theaters
  # POST /theaters.xml
  def create

    respond_to do |format|
      if @theater.save
        flash[:notice] = 'Theater was successfully created.'
        format.html { redirect_to(admin_theaters_path) }
        format.xml  { render :xml => @theater, :status => :created, :location => @theater }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @theater.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /theaters/1
  # PUT /theaters/1.xml
  def update

    respond_to do |format|
      if @theater.update_attributes(theater_params)
        flash[:notice] = 'Theater was successfully updated.'
        format.html { redirect_to(admin_theaters_path) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @theater.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /theaters/1
  # DELETE /theaters/1.xml
  def destroy
    @theater.destroy

    respond_to do |format|
      format.html { redirect_to(admin_theaters_url) }
      format.xml  { head :ok }
    end
  end

  def remove_empty_logo
    sub = params[:theater]
    if sub
      params[:theater].delete(:logo) if self.params[:theater][:logo].blank?
    end
  end

  private
  def theater_params
    params.require(:theater).permit(:name, :url, :theater_class, :status)
  end

end
