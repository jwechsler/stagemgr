class Admin::FestivalsController < Admin::ApplicationController
  load_and_authorize_resource

  def index
    @festivals = @festivals.order(:name)
  end

  def show; end

  def new; end

  def edit; end

  def create
    if @festival.save
      flash[:notice] = 'Festival was successfully created.'
      redirect_to admin_festivals_path
    else
      render action: 'new'
    end
  end

  def update
    @festival.update(festival_params)
    if @festival.save
      flash[:notice] = 'Festival was successfully updated.'
      redirect_to admin_festival_path(@festival)
    else
      render action: 'edit'
    end
  end

  def destroy
    if @festival.productions.any?
      flash[:alert] = 'This festival still has productions assigned. Unassign them before deleting the festival.'
      return redirect_to admin_festival_path(@festival)
    end

    @festival.destroy
    flash[:notice] = 'Festival was successfully deleted.'
    redirect_to admin_festivals_path
  end

  private

  def festival_params
    params.require(:festival).permit(:name, :slug, :description, :short_description, :status,
                                     :starts_on, :ends_on, :landing_page_enabled, :box_office_image)
  end
end
