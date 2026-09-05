# frozen_string_literal: true

require_relative 'app_secrets'

# Boot-time gate: refuse to serve production traffic with a secret missing.
#
# Replaces the commented-out `config.require_master_key` in production.rb, which
# only ever covered the credentials file. The failure we actually want to catch
# is broader (a blank ENV var, an unset gateway key) and the symptom without
# this check is a running site that silently 401s, 500s on checkout, or serves
# an unauthenticated Resque dashboard.
#
# secret_key_base is the one key Rails itself already guards: in production
# `validate_secret_key_base` raises when it resolves to nothing (the
# generate-a-random-one path is development/test only). Checking it here buys a
# far better message, and #legacy_secret_key_base? is defence in depth only --
# config/secrets.yml's production block reads ENV['SECRET_KEY_BASE'], the same
# variable AppSecrets already looks at, so it can only matter if that file is
# edited to hold a literal.
#
# Wired from config/initializers/app_secrets.rb, production only. Loaded with
# require_relative from config/application.rb (and Zeitwerk-ignored there).
module RequiredSecrets
  # Raised by .check!. Passenger renders it on the error page and Rails logs it
  # to log/production.log, which is the point: the message is the instructions.
  class Missing < StandardError; end

  SKIP_ENV = 'SKIP_REQUIRED_SECRETS_CHECK'

  # A rake process is exempt by default -- `assets:precompile`, `db:migrate` and
  # `setup:*` are exactly what an operator runs on a box that is not configured
  # yet, and failing them would make the situation unrecoverable. These prefixes
  # are the exception: `script/resque-worker` boots workers with
  # `rake environment resque:work`, and a worker without secrets is as broken as
  # a web process without them (it delivers all the mail).
  ENFORCED_TASK_PREFIXES = %w[resque:].freeze

  # What the operator loses while a warn-only secret is absent.
  CONSEQUENCES = {
    stripe_signing_secret: 'Until then Stripe webhooks are unverified, so subscription renewals and ' \
                           'refunds will not post back to the app.',
    resque_admin_password: 'Until then /admin/resque has no password: in production it is denied to ' \
                           'everyone, elsewhere it is open to anyone who can reach it.'
  }.freeze

  class << self
    # Should this process enforce the check?
    #
    # Rake is the interesting case: `assets:precompile`, `db:migrate` and
    # `setup:*` legitimately run on a box that has no secrets yet, but the
    # Resque workers boot through `rake environment resque:work`
    # (script/resque-worker) and must be held to the same bar as the web
    # process. Rake is not loaded at all inside Passenger, and a Rake
    # application that was never invoked from the command line has an empty
    # top_level_tasks -- so "no tasks" means "not a rake run".
    def enforce?(env: ENV, tasks: rake_task_names, console: console_or_runner?)
      return false if present?(env[SKIP_ENV])
      return false if console
      return false if tasks.any? && tasks.none? { |task| enforced_task?(task) }

      true
    end

    # Secret names this configuration must have. Depends on server.yml because a
    # theater on Postmark needs a Postmark token and one on sendmail does not.
    def required(server_config:)
      keys = [:secret_key_base]
      keys << :stripe_secret_key if stripe?(server_config)
      keys << :postmark_api_token if postmark?(server_config)
      keys
    end

    # The subset of .required that no source supplies. Array of registry names.
    def missing(server_config:)
      required(server_config: server_config).reject { |name| present_secret?(name) }
    end

    # Secrets whose absence degrades the app but does not stop it booting.
    def warn_only(server_config:)
      keys = [:resque_admin_password]
      keys << :stripe_signing_secret if stripe?(server_config)
      keys
    end

    # The subset of .warn_only that no source supplies; same shape as .missing.
    def warn_only_missing(server_config:)
      warn_only(server_config: server_config).reject { |name| present_secret?(name) }
    end

    # Raises Missing listing every absent secret and exactly where to put it.
    def check!(server_config:)
      warn_only_missing(server_config: server_config).each { |name| log_warning(name) }

      names = missing(server_config: server_config)
      return true if names.empty?

      raise Missing, message_for(names)
    end

    # One human-readable line per secret: what to set, where, what it costs while
    # it is unset, and the blank-ENV trap if that is what happened.
    def describe(name)
      parts = [AppSecrets.missing_message(name), CONSEQUENCES[name]]
      if AppSecrets.blank_env?(name)
        parts << "NOTE: ENV['#{AppSecrets.env_name(name)}'] is present but BLANK -- delete the line " \
                 'rather than leaving it empty; a blank value shadows the credential.'
      end
      parts.compact.join(' ')
    end

    private

    def message_for(names)
      [*credentials_key_warning,
       "Refusing to boot: #{names.size} required secret(s) are not configured.",
       *names.map { |name| "  - #{describe(name)}" },
       "Set them, or set #{SKIP_ENV}=1 to boot anyway (see the Developer manual, Credentials)."].join("\n")
    end

    # The trap this message exists to defuse: with the .enc present but no key,
    # ActiveSupport::EncryptedConfiguration#read swallows the MissingContentError
    # and returns {}, so every credential reads as nil and the advice above --
    # "add the credential" -- is advice the operator has already followed.
    def credentials_key_warning
      return [] unless AppSecrets.credentials_status == :no_key

      ["#{AppSecrets.credentials_file} exists but no decryption key was found " \
       '(the matching .key file next to it, config/master.key, or RAILS_MASTER_KEY) -- ' \
       'every credential reads as missing until the key is in place.']
    end

    def present_secret?(name)
      return true if AppSecrets[name]
      # Rails 6.1 resolves production secret_key_base as ENV || credentials ||
      # secrets.yml, and config/secrets.yml is still load-bearing here, so a key
      # only present there still counts.
      return legacy_secret_key_base? if name == :secret_key_base

      false
    end

    def legacy_secret_key_base?
      present?(Rails.application.secrets[:secret_key_base])
    rescue StandardError
      false
    end

    def stripe?(server_config)
      payment = dig_config(server_config, 'payment_processing') || {}
      %w[default_gateway default_recurring_gateway].any? { |key| dig_config(payment, key).to_s == 'stripe' }
    end

    def postmark?(server_config)
      email = dig_config(server_config, 'email') || {}
      dig_config(email, 'delivery_method').to_s == 'postmark'
    end

    # server.yml arrives as a HashWithIndifferentAccess in the app and as a plain
    # hash in specs; read both without caring.
    def dig_config(config, key)
      return nil unless config.respond_to?(:[])

      value = config[key]
      value.nil? ? config[key.to_sym] : value
    end

    def present?(value)
      !value.to_s.strip.empty?
    end

    def enforced_task?(task)
      ENFORCED_TASK_PREFIXES.any? { |prefix| task.to_s.start_with?(prefix) }
    end

    def rake_task_names
      return [] unless defined?(Rake) && Rake.respond_to?(:application)

      Array(Rake.application.top_level_tasks)
    rescue StandardError
      []
    end

    def console_or_runner?
      return true if defined?(Rails::Console)
      return true if defined?(Rails::Command::RunnerCommand)

      false
    end

    def log_warning(name)
      message = "[RequiredSecrets] #{describe(name)}"
      Kernel.warn(message)
      Rails.logger.warn(message) if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
    end
  end
end
