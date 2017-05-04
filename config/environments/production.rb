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

  # set this to any SubURI you may have running in passenger or its ilk, or blank if not

  config.action_controller.relative_url_root = '/tickets'

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

  config.assets.compress = true
  config.assets.js_compressor = :uglifier
  config.assets.compile = true
  config.assets.digest = true
  config.assets.precompile += %w( vendor/modernizr.js )

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
  Paperclip.options[:command_path] = "/usr/local/bin/"

  # Setup payments

  $PAYMENT_CONFIG = YAML::load(File.open("#{::Rails.root.to_s}/config/payment_processing.yml"))['production']

  config.after_initialize do
    PaymentProcessing.after_initialize
    MyEmma.set_credentials_from_yaml("#{self.root.to_s}/config/my_emma_credentials.yml")
  end

  $EMAIL_ADDRESS = YAML::load(File.open("#{::Rails.root.to_s}/config/emails.yml"))['production']
  $DATABASEDOTCOM = SalesforceSync.load_from_yaml_file('production',"#{::Rails.root.to_s}/config/databasedotcom.yml")
  config_data = YAML::load(File.open("#{::Rails.root.to_s}/config/server.yml"))
  $SERVER_CONFIG = config_data['all'].merge(config_data['production'])
  $EMAIL_ADDRESS = $SERVER_CONFIG['email_addresses']
  $TKTPRINT =  YAML::load(File.open("#{::Rails.root.to_s}/config/ticket_print.yml"))['production']

  config.action_mailer.default_url_options = { host: $SERVER_CONFIG['host'], protocol: $SERVER_CONFIG['host_protocol'] }

  # Set up notification for issues

end

Stagemgr::Application.config.middleware.use ExceptionNotification::Rack,
                        :email=> {
                          :email_prefix=>"[Stagemgr Exception] ",
                          :sender_address=>%{"Exception Notifier" <bugs@theaterwit.org>},
                          :exception_recipients=>%w{bugs@theaterwit.org}
                        }