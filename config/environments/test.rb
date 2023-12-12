require "active_support/core_ext/integer/time"

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  config.cache_classes = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = false

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => "public, max-age=#{1.hour.to_i}"
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Store uploaded files on the local file system in a temporary directory.
  config.active_storage.service = :test

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr.
  #config.active_support.deprecation = :stderr
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # ActiveSupport::Deprecation.debug = true
  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true


  config.after_initialize do
    ActiveMerchant::Billing::Base.mode = :test
    PaymentProcessing.after_initialize
    MyEmma.disable
  end

  # $TEST_CREDIT_CARD = paypal_config['test']['test_credit_card']

  $TKTPRINT =  YAML::load(File.open("#{::Rails.root.to_s}/config/ticket_print.yml"))['test']

  config_data = YAML::load(File.open("#{::Rails.root.to_s}/config/server.yml"))
  $SERVER_CONFIG = config_data['all'].merge(config_data['test'])
  $PAYMENT_CONFIG = $SERVER_CONFIG['payment_processing']
  $TEST_CREDIT_CARD = $PAYMENT_CONFIG['test_credit_card']
  $EMAIL_ADDRESS = $SERVER_CONFIG['email_addresses']
  $SERVER_CONFIG['ext_site_wrapper']='ext_test_wrapper'
  $RAND_CLAUSE = 1
  config.action_mailer.default_url_options = { host: $SERVER_CONFIG['host'], protocol: $SERVER_CONFIG['host_protocol'] }

  config.action_mailer.delivery_method = :test
  $APP_DISPLAY_NAME = ($SERVER_CONFIG['app_name'] || 'StageMgr') + " TEST"
  unless $SERVER_CONFIG['payment_processing'].nil? || $SERVER_CONFIG['payment_processing']['additional_card_types'].blank?
    $ADDITIONAL_CARD_TYPES = $SERVER_CONFIG['payment_processing']['additional_card_types'].split(',').map{|ct| ct.strip}
  else
    $ADDITIONAL_CARD_TYPES = []
  end
  
end
