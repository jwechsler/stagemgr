class UserSessionsController < ApplicationController
  def new
    @user_session = UserSession.new
  end

  def create
    @user_session = UserSession.new(user_session_params.to_h)
    if @user_session.save
      flash[:notice] = "Login successful!"
      redirect_to root_url
    else
      render :action => :new
    end
  end

  def destroy
    current_user_session.destroy unless current_user_session.nil?
    flash[:notice] = "Logout successful!"
    redirect_back_or_default new_user_session_url
  end

  private

  def user_session_params
      params.require(:user_session).permit(:email, :password, :remember_me)
  end


end
