class UserSessionsController < ApplicationController
  def new
    @user_session = UserSession.new
  end

  def create
    @user_session = UserSession.new(user_session_params.to_h)
    if @user_session.save
      flash[:notice] = "Login successful!"
      redirect_to account_url
    else
      render :action => :new
    end
  end

  def destroy
    current_user_session.destroy
    flash[:notice] = "Logout successful!"
    redirect_back_or_default new_user_session_url
  end

  private

  def user_session_params
      params.require(:user_session).permit(:email, :password, :remember_me)
  end


end

# class UserSessionsController < ApplicationController
#   skip_before_filter :require_login, :only=>[:new,:create]
#   def new
#     @user_session = UserSession.new
#   end
#
#   def create
#     @user_session = UserSession.new(params[:user_session].to_h)
#     if @user_session.save
#       flash[:notice] = "Login successful!"
#       redirect_back_or_default "/"
#     else
#       render :action => :new
#     end
#   end
#
#   def show
#     render '/general/unavailable', :layout=>'ext_site_wrapper'
#   end
#
#   def destroy
#     current_user_session.destroy
#     flash[:notice] = "Logout successful!"
#     redirect_back_or_default new_user_session_url
#   end
#
# end
