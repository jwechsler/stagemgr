require 'salesforce_sync'
#require 'httplog'

Stagemgr::Application.configure do
  # Settings specified here will take precedence over those in config/environment.rb

  config.action_controller.relative_url_root = ""

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the webserver when you make code changes.
  config.cache_classes = false

  # Asset management
  config.assets.compress = false
  #config.assets.compress = true

  #Expand the lines which load the assets
  config.assets.debug = true

  # test assets
  #config.assets.compress = true
  #config.assets.js_compressor = :uglifier
  #config.assets.compile = true
  #config.assets.digest = true


  config.eager_load = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = true

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log
  config.log_level = :info

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Setup paypal module

  $PAYMENT_CONFIG = YAML::load(File.open("#{::Rails.root.to_s}/config/payment_processing.yml"))['development']

  config.after_initialize do
    ActiveMerchant::Billing::Base.mode = :test
    PaymentProcessing.after_initialize
    MyEmma.set_credentials_from_yaml("#{self.root.to_s}/config/my_emma_credentials.yml")
    HttpLog.configure do |config|
      config.logger = Rails.logger
    end

  end

  config.external_site_root = 'file:///Users/jeremyw/dev/site'

  $DATABASEDOTCOM = SalesforceSync.load_from_yaml_file('development',"#{::Rails.root.to_s}/config/databasedotcom.yml")
  $TKTPRINT =  YAML::load(File.open("#{::Rails.root.to_s}/config/ticket_print.yml"))['development']
  config_data = YAML::load(File.open("#{::Rails.root.to_s}/config/server.yml"))
  $SERVER_CONFIG = config_data['all'].merge(config_data['development'])
  $EMAIL_ADDRESS = $SERVER_CONFIG['email_addresses']

  config.action_mailer.default_url_options = { host: $SERVER_CONFIG['host'], protocol: $SERVER_CONFIG['host_protocol'] }

  Paperclip.options[:log] = true

end

# unless $rails_rake_task
#   require 'ruby-debug'
#
#   Debugger.settings[:autoeval] = true
#   Debugger.settings[:autolist] = 1
#   Debugger.settings[:reload_source_on_change] = true
#   begin
#     Debugger.start_remote
#   rescue Exception => e
#     puts "Cannot start remote debugger - #{e.message}"
#   end

# end


