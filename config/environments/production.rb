Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Compress JavaScripts and CSS.
  config.assets.js_compressor = :uglifier
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # `config.assets.precompile` and `config.assets.version` have moved to config/initializers/assets.rb

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = 'http://assets.example.com'

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Mount Action Cable outside main process or domain
  # config.action_cable.mount_path = nil
  # config.action_cable.url = 'wss://example.com/cable'
  # config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Use the lowest log level to ensure availability of diagnostic information
  # when problems arise.
  config.log_level = :debug

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Use a real queuing backend for Active Job (and separate queues per environment)
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "stagemgr_#{Rails.env}"
  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require 'syslog/logger'
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new 'app-name')

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false
# Setup paperclip
  Paperclip.options[:command_path] = "/usr/local/bin/"

  # Setup payments

  $PAYMENT_CONFIG = YAML::load(File.open("#{::Rails.root.to_s}/config/payment_processing.yml"))['production']

  config.after_initialize do
    PaymentProcessing.after_initialize
    MyEmma.set_credentials_from_yaml("#{self.root.to_s}/config/my_emma_credentials.yml")
  end

  $DATABASEDOTCOM = SalesforceSync.load_from_yaml_file('production',"#{::Rails.root.to_s}/config/databasedotcom.yml")
  config_data = YAML::load(File.open("#{::Rails.root.to_s}/config/server.yml"))
  $SERVER_CONFIG = config_data['all'].merge(config_data['production'])
  $EMAIL_ADDRESS = $SERVER_CONFIG['email_addresses']
  $TKTPRINT =  YAML::load(File.open("#{::Rails.root.to_s}/config/ticket_print.yml"))['production']
  unless $SERVER_CONFIG['payment_processing'].nil? || $SERVER_CONFIG['payment_processing']['additional_card_types'].blank?
    $ADDITIONAL_CARD_TYPES = $SERVER_CONFIG['payment_processing']['additional_card_types'].split(',').map{|ct| ct.strip}
  else
    $ADDITIONAL_CARD_TYPES = []
  end

  $APP_DISPLAY_NAME = $SERVER_CONFIG['app_name'] || 'StageMgr'
  config.action_mailer.default_url_options = { host: "#{$SERVER_CONFIG['host']}#{$SERVER_CONFIG['sub_uri']}", protocol: $SERVER_CONFIG['host_protocol'] }

  # Set up notification for issues

end

# Exception notifications

Stagemgr::Application.config.middleware.use ExceptionNotification::Rack,
                        ignore_exceptions: ['ActiveRecord::RecordNotFound'] + ExceptionNotifier.ignored_exceptions,
                        :email=> {
                          :email_prefix=>"[Stagemgr Exception] ",
                          :sender_address=>%{"Exception Notifier" <bugs@theaterwit.org>},
                          :exception_recipients=>%w{bugs@theaterwit.org},
                          :delivery_method=>:sendmail
                        },
                        error_grouping: true