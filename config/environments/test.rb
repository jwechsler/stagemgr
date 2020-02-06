Stagemgr::Application.configure do
  # Settings specified here will take precedence over those in config/environment.rb

  # The test environment is used exclusively to run your application's
  # test suite.  You never need to work with it otherwise.  Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs.  Don't rely on the data there!
  config.cache_classes = true


  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  config.eager_load = false

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  config.action_controller.relative_url_root = ""

  # Raise exceptions instead of rendering exception templates
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment
  config.action_controller.allow_forgery_protection    = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper,
  # like if you have constraints or database-specific column types
  # config.active_record.schema_format = :sql

  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr


  # Turn off SQL Logging for development here
  config.after_initialize do
    ActiveRecord::Base.logger = Rails.logger.clone
    ActiveRecord::Base.logger.level = Logger::INFO
  end
  # Setup payment methods

  $PAYMENT_CONFIG = YAML::load(File.open("#{::Rails.root.to_s}/config/payment_processing.yml"))['test']
  $TEST_CREDIT_CARD = $PAYMENT_CONFIG['test_credit_card']
  $ADDITIONAL_CARD_TYPES = ['bogus']

  config.after_initialize do
    ActiveMerchant::Billing::Base.mode = :test
    PaymentProcessing.after_initialize
    MyEmma.set_credentials_from_yaml("#{self.root.to_s}/config/my_emma_credentials.yml")
    MyEmma.disable
  end


  # $TEST_CREDIT_CARD = paypal_config['test']['test_credit_card']

  $DATABASEDOTCOM = SalesforceSync.load_from_yaml_file('test',"#{::Rails.root.to_s}/config/databasedotcom.yml")

  $TKTPRINT =  YAML::load(File.open("#{::Rails.root.to_s}/config/ticket_print.yml"))['test']

  config_data = YAML::load(File.open("#{::Rails.root.to_s}/config/server.yml"))
  $SERVER_CONFIG = config_data['all'].merge(config_data['test'])
  $EMAIL_ADDRESS = $SERVER_CONFIG['email_addresses']
  config.action_mailer.default_url_options = { host: $SERVER_CONFIG['host'], protocol: $SERVER_CONFIG['host_protocol'] }

  config.action_mailer.delivery_method = :test
  $APP_DISPLAY_NAME = $SERVER_CONFIG['app_name'] || 'StageMgr'
  unless $SERVER_CONFIG['payment_processing'].nil? || $SERVER_CONFIG['payment_processing']['additional_card_types'].blank?
    $ADDITIONAL_CARD_TYPES = $SERVER_CONFIG['payment_processing']['additional_card_types'].split(',').map{|ct| ct.strip}
  else
    $ADDITIONAL_CARD_TYPES = []
  end

end
