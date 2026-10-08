require_relative 'boot'

# Belt-and-suspenders: also loaded in config/boot.rb. Repeated here so any
# entry point that bypasses boot.rb (webpacker:compile invoked outside the
# normal rails command chain, certain asset precompile flows, etc.) still
# has stdlib Logger defined before ActiveSupport reopens it.
require 'logger'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Secret resolution (ENV -> credentials -> deprecated server.yml) and the
# production boot gate. Required here, and ignored by the autoloader below,
# because the environment files use them before Zeitwerk is set up.
require_relative '../lib/app_secrets'
require_relative '../lib/required_secrets'

module Stagemgr
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    # app/models/<dir>/ only groups files: orders/ticket_order.rb defines
    # TicketOrder, not Orders::TicketOrder. Collapse the folders rather than adding
    # each as an autoload path -- Rails leaves autoload-only paths out of eager
    # loading, so production would load these models lazily and STI parents
    # (CurrencyPayment, PassPayment) would query only the subclasses loaded so far.
    Rails.autoloaders.main.collapse(Dir[Rails.root.join('app/models/*/')] - [Rails.root.join('app/models/concerns/').to_s])
    config.autoload_paths << "#{config.root}/lib"
    # config.eager_load_paths << "#{config.root}/lib"

    Rails.autoloaders.main.ignore("#{config.root}/lib/tasks")
    Rails.autoloaders.main.ignore(Rails.root.join('lib/extensions/my_emma_patches.rb'))
    Rails.autoloaders.main.ignore(Rails.root.join('lib/validates_credit_card.rb'))
    # Needed by config/initializers/site_theme.rb at boot, so loaded once there.
    Rails.autoloaders.main.ignore(Rails.root.join('lib/site_theme.rb'))
    # Required by the environment files, which run before the autoloaders are set up.
    Rails.autoloaders.main.ignore(Rails.root.join('lib/mailer_url_options.rb'))
    Rails.autoloaders.main.ignore(Rails.root.join('lib/app_secrets.rb'))
    Rails.autoloaders.main.ignore(Rails.root.join('lib/required_secrets.rb'))
    Rails.autoloaders.main.ignore(Rails.root.join('lib/exception_recipients.rb'))
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

    # Mount point (server.yml `sub_uri`, e.g. "/tickets") for every process.
    # Rails takes relative_url_root from RAILS_RELATIVE_URL_ROOT, which Passenger
    # exports for the web app but which a plain shell on the production box
    # does not have: `assets:precompile` run from bin/deploy baked font and
    # image URLs into the stylesheets without the prefix, so Font Awesome
    # icons rendered as empty boxes (2026-10). The environment file loads
    # server.yml; this fills the setting from it when the variable is absent
    # or blank. Blank counts as absent, as it does for AppSecrets: Compose
    # exports RAILS_RELATIVE_URL_ROOT="" when STAGEMGR_SUB_URI is unset, and
    # Rails seeds the setting from the variable verbatim. A non-blank value
    # still wins, so a Passenger base URI is never overridden. Skipped in
    # test: the suite's server.yml.example sets sub_uri to exercise the
    # mailer's sub-path handling, but its requests are made against unmounted
    # routes and would all 404 under a global prefix.
    initializer :relative_url_root_from_server_yml,
                after: :load_environment_config,
                before: :load_environment_hook do |app|
      next if Rails.env.test?

      sub_uri = app.config.x.server_config&.dig('sub_uri').presence
      app.config.relative_url_root = sub_uri if sub_uri && app.config.relative_url_root.blank?
    end

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = 'utf-8'

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += %i[password password_confirmation]

    # removed below with 4.2 update
    # config.action_view.javascript_expansions[:defaults] = %w(prototype rails)

    # use new error propogation methods. Removed in rails 5 update
    # config.active_record.raise_in_transactional_callbacks = true

    initializer :after_append_asset_paths,
                group: :all,
                after: :append_assets_path do |app|
      # Staff-authored copy that reaches public pages. safe_links_only drops
      # link and image targets outside http/https/mailto/ftp, so a
      # `[click](javascript:...)` in an offer description cannot become a live
      # link on the public membership index or a show page.
      #
      # Render options only take effect on a renderer INSTANCE: passed to
      # Markdown.new alongside the extensions, as `filter_html: true` was, they
      # are silently ignored -- so untrusted markdown has in fact been rendering
      # raw HTML through all along. Leaving it that way on purpose:
      # hundreds of existing show descriptions and every membership description
      # contain hand-written HTML, and switching filter_html on for real would
      # blank them. That is a decision about house data, not a config tweak.
      app.config.x.markdown = Redcarpet::Markdown.new(
        Redcarpet::Render::HTML.new(safe_links_only: true),
        autolink: true, space_after_headers: true
      )
      app.config.x.trusted_markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true,
                                                                                       space_after_headers: true)
      # Deprecated compatibility shim for the markdown renderers. These run in a
      # late initializer (after config/initializers load), so they are aliased
      # here rather than in config/initializers/legacy_globals.rb to capture the
      # real renderer object. New code must use Rails.configuration.x.markdown /
      # .trusted_markdown. Remove after external forks migrate.
      $MARKDOWN = app.config.x.markdown # rubocop:disable Style/GlobalVars
      $TRUSTED_MARKDOWN = app.config.x.trusted_markdown # rubocop:disable Style/GlobalVars
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
