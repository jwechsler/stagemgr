class ApplicationController < ActionController::Base
  helper :all
  helper_method :current_user_session, :current_user, :logged_in?, :current_user_is_admin?, :payment_types_for,
                :backend_user?

  # RAILS_RAISE_ERRORS disables the global rescue so the real exception (with
  # backtrace) surfaces in test runs instead of collapsing into a redirect loop.
  rescue_from StandardError, with: :handle_exception unless Rails.env.development? || ENV['RAILS_RAISE_ERRORS'].present?

  # Must stay below the StandardError rescue: Rails tries handlers last-declared
  # first, so declared above it this was shadowed and every denial was mailed
  # to ExceptionNotifier as an unexpected error.
  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.json { head :forbidden, content_type: 'text/html' }
      format.html { redirect_to main_app.root_url, notice: exception.message }
      format.js   { head :forbidden, content_type: 'text/html' }
    end
  end

  attr_accessor :markdown

  def payment_types_for(order, frontend = true)
    types = order.valid_payment_types_for(current_user)
    if frontend
      types.select { |t| t.allow_for_public? }
    else
      types
    end
  end

  def backend_user?
    current_user && (current_user.is_administrator? || current_user.is_box_office_user?)
  end

  def method_missing(method, *args, &)
    begin
      method_name = method.to_s
      if method_name =~ /^find_/
        match_data = method_name.match(/^find_(.*)$/)
        model_name = match_data[1]
        model_class = model_name.classify.constantize
        param_id = :"#{model_name}_id"
        found_model = if params[param_id]
                        model_class.find(params[param_id])
                      elsif params[:id]
                        model_class.find(params[:id])
                      end
        instance_variable_set "@#{model_name}", found_model if found_model
        return
      end
    rescue StandardError
      # just do standard method_missing stuff if we fail
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
    render '/general/unavailable', status: :not_found
  end

  protected

  def clear_authlogic_session
    sess = current_user_session
    sess.destroy if sess
  end

  def require_login
    return if current_user

    respond_to do |format|
      format.html do
        session[:return_to] = request.url
        flash[:error] = 'You must be logged in to access this page'
        redirect_to new_user_session_path
      end
      format.xml do
        user = User.new
        user.errors.add(:base, 'Authentication is required.')
        render xml: user.errors, status: :unauthorized
      end
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

    # Notify an external service (optional). exception_notification is bundled
    # for :production and :test only; the rescue_from above already skips
    # development, so the guard is belt-and-braces against a NameError raised
    # inside the rescue handler itself.
    ExceptionNotifier.notify_exception(exception, env: request.env) if defined?(ExceptionNotifier)

    # Set the flash message with the exception
    flash[:error] =
      "An unexpected error occurred at #{request.fullpath}: #{exception.message}. An error report has been filed with the administrator"

    if referer_safe_after_error?
      redirect_back(fallback_location: root_path)
    else
      redirect_to root_path
    end
  end

  # Only go back to a referer on this host (never send someone to a foreign
  # site from an error page, and never raise UnsafeRedirectError here once
  # raise_on_open_redirects is on), and not to the page that just failed,
  # which would loop.
  def referer_safe_after_error?
    return false if request.referer.blank?

    referer = URI.parse(request.referer)
    referer.host == request.host && referer.path != request.path
  rescue URI::InvalidURIError
    false
  end

  def store_location
    if is_a?(UserSessionsController)
      # don't store
    elsif request.format == :json
      # don't store
    else
      session[:return_to] = request.url
    end
  end

  def redirect_back_or_default(default)
    redirect_to(session[:return_to] || default)
    session[:return_to] = nil
  end
end
