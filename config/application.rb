require File.expand_path('../boot', __FILE__)

require 'rails/all'

require "#{File.dirname(__FILE__)}/../lib/salesforce_sync"
require "#{File.dirname(__FILE__)}/../lib/my_emma_patches"

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, :assets, Rails.env) if defined?(Bundler)

# load resque front end
require 'resque/server'

module Stagemgr
  class Application < Rails::Application

    # Set the i18n default to false to accomodate old default behavior (in old credit card validator)
    # @todo once this gem has been updated, remove this

    config.i18n.enforce_available_locales = false

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)
    config.autoload_paths += %W( #{config.root}/app/models/orders #{config.root}/app/models/payments #{config.root}/app/models/special_offers #{config.root}/app/models/line_items #{config.root}/app/models/payment_types #{config.root}/app/models/order_tasks #{config.root}/app/models/tktprint #{config.root}/app/models/resque_jobs #{config.root}/app/models/reports)
    config.autoload_paths += %W( #{config.root}/lib )
    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Central Time (US & Canada)'
    config.active_record.default_timezone = :utc

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # hide credit card parameters.

    config.filter_parameters << :password << :credit_card_number << :card_number << :credit_card_verification_number << :credit_card_expiration_month << :credit_card_expiration_year

    # If you want to use gmail for deliver...
    #config.action_mailer.delivery_method = :smtp
    #config.action_mailer.smtp_settings = {
    #  :enable_starttls_auto => true,
    #  :address => 'smtp.gmail.com',
    #  :port => 587,
    #  :domain => 'yourdomain.org',
    #  :authentication => :plain,
    #  :user_name => 'user@yourdomain.org',
    #  :password => 'yourpassword'
    #}

    #  Or set up postmark (get account at postmarkapp.com). Right now, only email to production settings implemeneted...
    email_config =  YAML::load(File.open("#{::Rails.root.to_s}/config/email_credentials.yml"))

    config.action_mailer.delivery_method   = :postmark
    config.action_mailer.postmark_settings = { :api_key=>email_config['api_key'] }
    config.action_mailer.raise_delivery_errors = true
    # JavaScript files you want as :defaults (application.js is always included).
    # config.action_view.javascript_expansions[:defaults] = %w(jquery rails)

    config.assets.enabled = true
    config.assets.version = '1.0'
    config.assets.prefix = '/assets'


    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password, :password_confirmation]

    # removed below with 4.2 update
    # config.action_view.javascript_expansions[:defaults] = %w(prototype rails)

    # use new error propogation methods
    config.active_record.raise_in_transactional_callbacks = true

    initializer :after_append_asset_paths,
            :group => :all,
            :after => :append_assets_path do
        config.assets.paths.unshift Rails.root.join("app", "assets", "stylesheets", "jquery", "cupertino").to_s

        $MARKDOWN = Redcarpet::MarkdownExtension.new(Redcarpet::Render::HTML, :autolink => true, :space_after_headers => true, :filter_html=>true)
        $TRUSTED_MARKDOWN = Redcarpet::MarkdownExtension.new(Redcarpet::Render::HTML, :autolink => true, :space_after_headers => true)

    end

    #limit Audits to 25 changes
    Audited.max_audits = 25
  end
end
