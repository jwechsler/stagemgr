
class ApplicationController < ActionController::Base
  helper :all
  helper_method :current_user_session, :current_user, :logged_in?, :current_user_is_admin?, :payment_types_for, :backend_user?

  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.json { head :forbidden, content_type: 'text/html' }
      format.html { redirect_to main_app.root_url, notice: exception.message }
      format.js   { head :forbidden, content_type: 'text/html' }
    end
  end

  unless Rails.env.development?
    rescue_from StandardError, with: :handle_exception
  end

  attr_accessor :markdown

  def payment_types_for(order, frontend = true)
    types = order.valid_payment_types_for(current_user)
    if frontend
      types.select{|t| t.allow_for_public? }
    else
      types
    end
  end

  def backend_user?
    current_user && (current_user.is_administrator? || current_user.is_box_office_user?)
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

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.record
  end

  def parse_date_param(key, default:)
    return default if params[key].blank?
    Date.parse(params[key])
  rescue ArgumentError, TypeError
    default
  end


  def index
    render '/general/unavailable', :status=>404
  end

  protected

  def clear_authlogic_session
    sess = current_user_session
    sess.destroy if sess
  end

  def require_login
    unless current_user
      respond_to do |format|
        format.html {
          session[:return_to] = request.url
          flash[:error] = "You must be logged in to access this page"
          redirect_to new_user_session_path
        }
      format.xml {
        user = User.new
        user.errors.add(:base, "Authentication is required.")
        render :xml => user.errors, :status => 401
      }
      end
    return false
    end
  end

 
  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end

  private

  def handle_exception(exception)
   # Log the exception
    Rails.logger.error "Exception: #{exception.message}"
   Rails.logger.error exception.backtrace.join("\n")

   # Notify an external service (optional)
   ExceptionNotifier.notify_exception(exception, env: request.env)

   # Set the flash message with the exception
   flash[:error] = "An unexpected error occurred at #{request.fullpath}: #{exception.message}. An error report has been filed with the administrator"

   # Prevent redirect loop by checking if referer is the same as current request path
   referer = request.referer
   current_path = request.fullpath

   if referer && URI(referer).path != current_path
     redirect_to referer
   else
     # Fallback to a safe path if referer is not available or matches the current path
     redirect_to root_path
   end
 end


  def store_location
    case
    when self.is_a?(UserSessionsController)
      #don't store
    when request.format == :json
      #don't store
    else
      session[:return_to] = request.url
    end
  end

  def redirect_back_or_default(default)
    redirect_to(session[:return_to] || default)
    session[:return_to] = nil
  end

end
