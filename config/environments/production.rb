require "active_support/core_ext/integer/time"

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

  # Ensures that a master key has been made available in either ENV["RAILS_MASTER_KEY"]
  # or in config/master.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Compress CSS using a preprocessor.
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = 'http://assets.example.com'

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = 'wss://example.com/cable'
  # config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Include generic and useful information about system operation, but avoid logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII).
  config.log_level = :info

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # Rotate logs when they reach 100 MB, with a history of 10 logs
  config.logger = Logger.new(config.paths['log'].first, 10, 100.megabytes)

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Use a real queuing backend for Active Job (and separate queues per environment).
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "stagemgr_production"

  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Log disallowed deprecations.
  config.active_support.disallowed_deprecation = :log

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require "syslog/logger"
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new 'app-name')

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Inserts middleware to perform automatic connection switching.
  # The `database_selector` hash is used to pass options to the DatabaseSelector
  # middleware. The `delay` is used to determine how long to wait after a write
  # to send a subsequent read to the primary.
  #
  # The `database_resolver` class is used by the middleware to determine which
  # database is appropriate to use based on the time delay.
  #
  # The `database_resolver_context` class is used by the middleware to set
  # timestamps for the last write to the primary. The resolver uses the context
  # class timestamps to determine how long to wait before reading from the
  # replica.
  #
  # By default Rails will store a last write timestamp in the session. The
  # DatabaseSelector middleware is designed as such you can define your own
  # strategy for connection switching and pass that into the middleware through
  # these configuration options.
  # config.active_record.database_selector = { delay: 2.seconds }
  # config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
  # config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
# Setup payments

  config.after_initialize do
    PaymentProcessing.after_initialize
    unless Rails.application.credentials.dig(:my_emma,:account_id).nil?
      MyEmma.set_credentials(Rails.application.credentials.dig(:my_emma,:username), Rails.application.credentials.dig(:my_emma, :password), Rails.application.credentials.dig(:my_emma,:account_id)) 
    else
      MyEmma.disable
    end
  end

  config_data = YAML::load(File.open("#{::Rails.root.to_s}/config/server.yml"))
  $SERVER_CONFIG = config_data['all'].deep_merge(config_data['production'])
  $EMAIL_ADDRESS = $SERVER_CONFIG['email']['addresses']
  $PAYMENT_CONFIG = $SERVER_CONFIG['payment_processing']
  $SERVER_CONFIG['ext_site_wrapper']=$SERVER_CONFIG['ext_site_wrapper'] || 'ext_site_wrapper'
  $TKTPRINT =  YAML::load(File.open("#{::Rails.root.to_s}/config/ticket_print.yml"))['production']
  unless $SERVER_CONFIG['payment_processing'].nil? || $SERVER_CONFIG['payment_processing']['additional_card_types'].blank?
    $ADDITIONAL_CARD_TYPES = $SERVER_CONFIG['payment_processing']['additional_card_types'].split(',').map{|ct| ct.strip}
  else
    $ADDITIONAL_CARD_TYPES = []
  end

  config.action_mailer.delivery_method   = $SERVER_CONFIG['email']['delivery_method'].to_sym
  if $SERVER_CONFIG['email']['delivery_method'].eql?('postmark')
    config.action_mailer.postmark_settings = { :api_key=>Rails.application.credentials.dig(:postmark_api_token) }
  end

  $RAND_CLAUSE = Arel.sql('RAND()')
  $APP_DISPLAY_NAME = $SERVER_CONFIG['app_name'] || 'StageMgr'
  config.action_mailer.default_url_options = { host: "#{$SERVER_CONFIG['host']}#{$SERVER_CONFIG['sub_uri']}", protocol: $SERVER_CONFIG['host_protocol'] }
  Rails.application.routes.default_url_options[:host] = $SERVER_CONFIG['host']

  # Set up notification for issues

end

# Exception notifications

Stagemgr::Application.config.middleware.use ExceptionNotification::Rack,
                        ignore_exceptions: ['ActionController::InvalidAuthenticityToken','ActiveRecord::RecordNotFound'] + ExceptionNotifier.ignored_exceptions,
                        :email=> {
                          :email_prefix=>"[Stagemgr Exception] ",
                          :sender_address=>%{"Exception Notifier" <bugs@theaterwit.org>},
                          :exception_recipients=>%w{bugs@theaterwit.org},
                          :delivery_method=>:sendmail
                        },
                        error_grouping: true

