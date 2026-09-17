require_relative '../../lib/mailer_url_options'

require 'active_support/core_ext/integer/time'

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
  # Run jobs in the calling thread. The default :async adapter runs
  # ActiveStorage's analyze job on a second thread the moment a spec attaches a
  # blob; that thread's database traffic tramples the example's connection and
  # the process dies inside mysql2 (Lost connection to MySQL server -> SIGSEGV).
  config.active_job.queue_adapter = :inline

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr.
  # config.active_support.deprecation = :stderr
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

  # config.x.test_credit_card is assigned from config.x.payment_config below.

  # Application configuration loaded from YAML. The loaded objects are kept
  # exactly as parsed (string-keyed Hashes) and assigned to config.x.* so that
  # existing string-key access (e.g. config.x.server_config['host']) keeps
  # working. Legacy $GLOBALS alias these via config/initializers/legacy_globals.rb.
  config.x.tktprint = (YAML.load(File.open(Rails.root.join('config/ticket_print.yml').to_s)) || {})['test']

  # The test environment reads the TRACKED config/server.yml.example, not the
  # developer's gitignored config/server.yml, so every checkout and CI run sees
  # the same fixture values (the `test:` block carries sentinel facts such as
  # theater.phone "555-BOX-OFFICE" that specs assert on).
  config_data = YAML.load(File.open(Rails.root.join('config/server.yml.example').to_s)) || {}
  config.x.server_config = (config_data['all'] || {}).deep_merge(config_data['test'] || {}).with_indifferent_access
  config.x.payment_config = config.x.server_config['payment_processing'] || {}
  config.x.test_credit_card = config.x.payment_config['test_credit_card']
  config.x.email_address = config.x.server_config.dig('email', 'addresses')
  config.x.server_config['ext_site_wrapper'] = 'standalone'
  config.x.rand_clause = 1
  config.action_mailer.default_url_options = MailerUrlOptions.for(config.x.server_config)

  config.action_mailer.delivery_method = :test
  config.x.app_display_name = "#{config.x.server_config['app_name'] || 'StageMgr'} TEST"
  if config.x.server_config['payment_processing'].nil? ||
     config.x.server_config['payment_processing']['additional_card_types'].blank?
    config.x.additional_card_types = []
  else
    config.x.additional_card_types =
      config.x.server_config['payment_processing']['additional_card_types'].split(',').map(&:strip)
  end
end
