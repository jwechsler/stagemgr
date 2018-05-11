class UserSessionsController < ApplicationController
  skip_before_filter :require_login, :only=>[:new,:create]
  def new
    @user_session = UserSession.new
  end

  def create
    @user_session = UserSession.new(params[:user_session].to_h)
    if @user_session.save
      flash[:notice] = "Login successful!"
      redirect_back_or_default '/'
    else
      render :action => :new
    end
  end

  def show
    render '/general/unavailable', :layout=>'ext_site_wrapper'
  end

  def destroy
    current_user_session.destroy
    flash[:notice] = "Logout successful!"
    redirect_back_or_default new_user_session_url
  end

end
