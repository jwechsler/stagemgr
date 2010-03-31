class Admin::UsersController < Admin::ApplicationController
  prepend_before_filter :find_user, :only => [:show, :edit, :update, :destroy]
  
  # GET /users
  def index
    @users = User.all

    respond_to do |format|
      format.html # index.html.erb
    end
  end
  
  def new
    @user = User.new
  end
  
  def create
    @user = User.new(params[:user])
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
    if @user.update_attributes(params[:user])
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
    redirect_to root_path
  end
  
  private
  
  def find_user
    @user = User.find(params[:id])
  end

end
