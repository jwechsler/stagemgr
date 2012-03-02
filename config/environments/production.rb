Stagemgr::Application.configure do
  # Settings specified here will take precedence over those in config/environment.rb

  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Specifies the header that your server uses for sending files
  config.action_dispatch.x_sendfile_header = "X-Sendfile"

  # For nginx:
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect'

  # If you have no front-end server that supports something like X-Sendfile,
  # just comment this out and Rails will serve the files

  # See everything in the log (default is :info)
  # config.log_level = :debug

  # Use a different logger for distributed setups
  # config.logger = SyslogLogger.new

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Disable Rails's static asset server
  # In production, Apache or nginx will already do this
  # config.serve_static_assets = true

  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify
  # Setup paperclip
  Paperclip.options[:command_path] = "/usr/local/Cellar/imagemagick/6.6.9-4/bin/"

  # Setup paypal
  config.after_initialize do
    pem_file = File.read("#{::Rails.root.to_s}/config/cert_key_pem_prod.txt")
    ActiveMerchant::Billing::PaypalGateway.pem_file = pem_file
    ActiveMerchant::Billing::PaypalRecurringGateway.pem_file = pem_file

    paypal_config = YAML::load(File.open("#{::Rails.root.to_s}/config/pay_pal_credentials.yml"))

    $PAYPAL_LOGIN = paypal_config['production']['paypal_login']
    $PAYPAL_PASSWORD = paypal_config['production']['paypal_password']

    $DATABASEDOTCOM = SalesforceSync.load_from_yaml_file('production',"#{::Rails.root.to_s}/config/databasedotcom.yml")


  end

  $EMAIL_ADDRESS = YAML::load(File.open("#{::Rails.root.to_s}/config/emails.yml"))['production']


  $TKTPRINT =  YAML::load(File.open("#{::Rails.root.to_s}/config/ticket_print.yml"))['production']

  # Set up notification for issues

  config.middleware.use ExceptionNotifier,
                        :email_prefix=>"[Stagemgr Exception] ",
                        :sender_address=>%{"Exception Notifier" <bugs@theaterwit.org>},
                        :exception_recipients=>%w{bugs@theaterwit.org}
end
