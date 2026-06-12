require 'active_support/core_ext/integer/time'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Use a real queuing backend for Active Job (and separate queues per environment).
  config.active_job.queue_adapter = :inline

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Setup paypal module

  config.after_initialize do
    ActiveMerchant::Billing::Base.mode = :test
    PaymentProcessing.after_initialize
    if Rails.application.credentials.dig(:my_emma, :account_id).nil?
      MyEmma.read_only!
    else
      MyEmma.set_credentials(Rails.application.credentials.dig(:my_emma, :username),
                             Rails.application.credentials.dig(:my_emma, :password), Rails.application.credentials.dig(:my_emma, :account_id))
    end
  end

  config.external_site_root = 'file:///Users/jeremyw/dev/site'

  # Application configuration loaded from YAML. The loaded objects are kept
  # exactly as parsed (string-keyed Hashes) and assigned to config.x.* so that
  # existing string-key access (e.g. config.x.server_config['host']) keeps
  # working. Legacy $GLOBALS alias these via config/initializers/legacy_globals.rb.
  config.x.tktprint = YAML.load(File.open(Rails.root.join('config/ticket_print.yml').to_s))['development']
  config_data = YAML.load(File.open(Rails.root.join('config/server.yml').to_s))
  config.x.server_config = config_data['all'].deep_merge(config_data['development'])
  config.x.payment_config = config.x.server_config['payment_processing']
  config.x.server_config['ext_site_wrapper'] = config.x.server_config['ext_site_wrapper'] || 'ext_site_wrapper'
  config.x.email_address = config.x.server_config['email']['addresses']
  config.action_mailer.default_url_options = { host: config.x.server_config['host'],
                                               protocol: config.x.server_config['host_protocol'] }
  config.x.rand_clause = Arel.sql('RAND()')

  config.action_mailer.delivery_method = config.x.server_config['email']['delivery_method'].to_sym
  if config.x.server_config['email']['delivery_method'].eql?('postmark')
    config.action_mailer.postmark_settings = { api_key: Rails.application.credentials[:postmark_api_token] }
  end

  if config.x.server_config['payment_processing'].nil? ||
     config.x.server_config['payment_processing']['additional_card_types'].blank?
    config.x.additional_card_types = []
  else
    config.x.additional_card_types =
      config.x.server_config['payment_processing']['additional_card_types'].split(',').map(&:strip)
  end
  config.x.app_display_name = config.x.server_config['app_name'] || 'StageMgr'
  Rails.application.routes.default_url_options[:host] = config.x.server_config['host']

  # Allow binding from ngrok.io for remote testing
  config.hosts << 'jw-macbook-m4'
  config.hosts << /.*\.ngrok\.io/
  config.hosts << /.*\.ngrok\.app/
end
