class Admin::ApplicationController < ApplicationController
  before_filter :admin_only
  
  protected
  
  def admin_only
    if current_user.nil? || !current_user.is_administrator
      store_location
      flash[:notice] = "Restricted Access"
      redirect_to '/' and return
    end
  end
end
