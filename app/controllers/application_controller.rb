class ApplicationController < ActionController::Base
  helper :all
  helper_method :current_user_session, :current_user, :logged_in?, :current_user_is_admin?
  filter_parameter_logging :password, :password_confirmation

  protected

  def clear_authlogic_session
    sess = current_user_session
    sess.destroy if sess
  end
  
  private
    def current_user_session
      return @current_user_session if defined?(@current_user_session)
      @current_user_session = UserSession.find
    end
    
    def current_user
      return @current_user if defined?(@current_user)
      @current_user = current_user_session && current_user_session.record
    end
    
    def store_location
      case
      when self.is_a?(UserSessionsController)
        #don't store
      when request.format == :json
        #don't store
      else
        session[:return_to] = request.request_uri
      end
    end
    
    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end
end
