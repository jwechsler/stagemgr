class Admin::TheatersController < Admin::ApplicationController
  before_action :remove_empty_logo
  load_and_authorize_resource except: [:autocomplete_tag]

  before_action :find_context, only: :show

  respond_to :html, :json

  def autocomplete_tag
    term = params[:term].to_s
    names = TheaterTag.where('name LIKE ?', "#{term}%")
                      .order(:name).limit(20).pluck(:name).uniq
    render json: names
  end

  def index
    @theaters = @theaters.sort_by { |t| [t.status, t.theater_class, t.name] }

    @theaters = @theaters.select { |t| current_user.theaters.include?(t) } if current_user.is_theater_user?
    respond_to do |format|
      format.html # index.html.erb
      format.json do
        params.permit!
        render json: TheaterDatatable.new(params, view_context: view_context, current_user: current_user)
      end
    end
  end

  def show; end

  # GET /theaters/new
  # GET /theaters/new.xml
  def new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render xml: @theater }
    end
  end

  def edit; end

  # POST /theaters
  # POST /theaters.xml
  def create
    respond_to do |format|
      if @theater.save
        flash[:notice] = 'Theater was successfully created.'
        format.html { redirect_to(admin_theaters_path) }
        format.xml  { render xml: @theater, status: :created, location: @theater }
      else
        format.html { render action: 'new' }
        format.xml  { render xml: @theater.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /theaters/1
  # PUT /theaters/1.xml
  def update
    respond_to do |format|
      if @theater.update(theater_params)
        flash[:notice] = 'Theater was successfully updated.'
        format.html { redirect_to(admin_theaters_path) }
        format.xml  { head :ok }
      else
        format.html { render action: 'edit' }
        format.xml  { render xml: @theater.errors, status: :unprocessable_entity }
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
    return unless sub

    params[:theater].delete(:logo) if params[:theater][:logo].blank?
  end

  private

  def theater_params
    params.require(:theater).permit(:name, :url, :theater_class, :logo, :status, :default_service_items,
                                    :default_first_exchange_items, :default_addl_exchange_items, :accepts_donations, :myemma_attendee_group, :tag_names)
  end
end
