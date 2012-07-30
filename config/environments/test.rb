Stagemgr::Application.configure do
  # Settings specified here will take precedence over those in config/environment.rb

  # The test environment is used exclusively to run your application's
  # test suite.  You never need to work with it otherwise.  Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs.  Don't rely on the data there!
  config.cache_classes = true

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

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

  # Setup paypal
  config.after_initialize do
    ActiveMerchant::Billing::Base.gateway_mode = :test
    ActiveMerchant::Billing::PaypalGateway.pem_file = File.read("#{::Rails.root.to_s}/config/cert_key_pem_dev.txt")
  end

  paypal_config = YAML::load(File.open("#{::Rails.root.to_s}/config/pay_pal_credentials.yml"))

  $PAYPAL_LOGIN = paypal_config['test']['paypal_login']
  $PAYPAL_PASSWORD = paypal_config['test']['paypal_password']
  $TEST_CREDIT_CARD = paypal_config['test']['test_credit_card']

  $DATABASEDOTCOM = SalesforceSync.load_from_yaml_file('test',"#{::Rails.root.to_s}/config/databasedotcom.yml")

  $TKTPRINT =  YAML::load(File.open("#{::Rails.root.to_s}/config/ticket_print.yml"))['test']

  $EMAIL_ADDRESS = YAML::load(File.open("#{::Rails.root.to_s}/config/emails.yml"))['test']

end
