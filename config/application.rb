require_relative "boot"

# Belt-and-suspenders: also loaded in config/boot.rb. Repeated here so any
# entry point that bypasses boot.rb (webpacker:compile invoked outside the
# normal rails command chain, certain asset precompile flows, etc.) still
# has stdlib Logger defined before ActiveSupport reopens it.
require "logger"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Stagemgr
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    config.autoload_paths += Dir[Rails.root.join('app', 'models', '**/')]
    config.autoload_paths << "#{config.root}/lib"
    # config.eager_load_paths << "#{config.root}/lib"

    Rails.autoloaders.main.ignore("#{config.root}/lib/tasks")
    Rails.autoloaders.main.ignore(Rails.root.join('lib/my_emma_patches.rb'))
    Rails.autoloaders.main.ignore(Rails.root.join('lib/validates_credit_card.rb'))
    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Central Time (US & Canada)'
    config.active_record.default_timezone = :local
    config.active_record.time_zone_aware_attributes = false
    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # If you want to use gmail for deliver...
    # config.action_mailer.delivery_method = :smtp
    # config.action_mailer.smtp_settings = {
    #  :enable_starttls_auto => true,
    #  :address => 'smtp.gmail.com',
    #  :port => 587,
    #  :domain => 'yourdomain.org',
    #  :authentication => :plain,
    #  :user_name => 'user@yourdomain.org',
    #  :password => 'yourpassword'
    # }

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

    # use new error propogation methods. Removed in rails 5 update
    # config.active_record.raise_in_transactional_callbacks = true

    initializer :after_append_asset_paths,
                :group => :all,
                :after => :append_assets_path do
      $MARKDOWN = Redcarpet::Markdown.new(Redcarpet::Render::HTML, :autolink => true, :space_after_headers => true,
                                                                   :filter_html => true)
      $TRUSTED_MARKDOWN = Redcarpet::Markdown.new(Redcarpet::Render::HTML, :autolink => true,
                                                                           :space_after_headers => true)
    end

    # manage yaml deserialization of audit records for ruby type safety workaround
    config.active_record.yaml_column_permitted_classes =
      %w[String Integer NilClass Float Time Date FalseClass Hash Array DateTime TrueClass BigDecimal
         ActiveSupport::TimeWithZone ActiveSupport::TimeZone ActiveSupport::HashWithIndifferentAccess]
    # limit Audits to 25 changes
    Audited.max_audits = 25

    config.active_storage.variant_processor = :vips
    config.active_storage.queue = :maintenance
  end
end
