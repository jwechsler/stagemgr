# lib/middleware/catch_exceptions.rb
class CatchExceptions
  def initialize(app)
    @app = app
  end

  def call(env)
    begin
      @app.call(env)
    rescue => exception
      request = Rack::Request.new(env)
      flash = ActionDispatch::Flash::FlashHash.new(env['rack.session'])
      flash[:error] = "Sorry! An unexpected error has occurred [#{exception.message}]. The developer has been notified"

      # Log the error
      Rails.logger.error exception.message
      Rails.logger.error exception.backtrace.join("\n")

      # Notify via ExceptionNotification
      ExceptionNotifier.notify_exception(exception, env: env)

      # Redirect to the original path or a fallback path
      [302, {'Location' => request.referer || '/', 'Content-Type' => 'text/html'}, []]
    end
  end
end
