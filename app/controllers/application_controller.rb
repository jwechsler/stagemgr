class ApplicationController < ActionController::Base
  helper :all
  helper_method :current_user_session, :current_user, :logged_in?, :current_user_is_admin?, :payment_types_for
  filter_parameter_logging :password, :password_confirmation
  
  
  def payment_types_for(order)
    order.valid_payment_types_for( current_user)
  end
    
  def method_missing(method, *args, &block)
    begin
      method_name = method.to_s
      if method_name =~ /^find_/
        match_data = method_name.match(/^find_(.*)$/)
        model_name = match_data[1]
        model_class = model_name.classify.constantize
        param_id = "#{model_name}_id".to_sym
        found_model = if params[param_id]
          model_class.find(params[param_id])
        elsif params[:id]
          model_class.find(params[:id])
        else
          nil
        end
        if found_model
          instance_variable_set "@#{model_name}", found_model
        end
        return
      end
    rescue StandardError => e
      #just do standard method_missing stuff if we fail
    end
    super
  end

  protected

  def clear_authlogic_session
    sess = current_user_session
    sess.destroy if sess
  end
  
  def require_login
    if current_user.nil?
      store_location
      flash[:notice] = "Log in"
      redirect_to new_user_session_path and return
    end
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
