class Admin::UsersController < Admin::ApplicationController
  load_and_authorize_resource
  # prepend_before_action :find_user, :only => [:show, :edit, :update, :destroy]

  # GET /users
  def index
    @users = User.all

    respond_to do |format|
      format.html # index.html.erb
      format.json {
        params.permit!
        render json: UserDatatable.new(params, view_context: view_context, current_user: current_user )
      }
    end
  end

  def new
  end

  def create
    if @user.save
      flash[:notice] = "Account registered!"
      redirect_back_or_default admin_users_path
    else
      render :action => :new
    end
  end

  def show; end

  def edit; end

  def update
    @user.update_attributes(user_params)
    if @user.save
      flash[:notice] = "Account updated!"
      redirect_to admin_users_path
    else
      render :action => :edit
    end
  end

  def destroy
    if current_user_is_admin?
      user = User.find(params[:id])
      user.destroy
      flash[:notice] = "User #{user.login} deleted!"
    end
    redirect_to root_url
  end

  private

  def find_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email,:password,:password_confirmation,:status,:is_administrator,:is_box_office_user, :theater_ids=>[])
  end
end
