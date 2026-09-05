# frozen_string_literal: true

# Required explicitly rather than relying on the host: this file is loaded from
# config/application.rb before the framework is initialized.
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/module/delegation'

# Single resolution point for every secret the application needs.
#
# Resolution order, per key:
#
#   1. ENV       -- blank ("" or whitespace) counts as absent and falls through.
#   2. encrypted credentials -- whatever `Rails.application.credentials` points
#      at. Rails 6.1 prefers the per-environment pair
#      config/credentials/<env>.yml.enc + config/credentials/<env>.key (or
#      RAILS_MASTER_KEY) when the .enc for the current environment exists, and
#      otherwise falls back to config/credentials.yml.enc + config/master.key.
#      Both shapes are in play here: development and test use per-environment
#      files, Theater Wit's production box uses the shared pair.
#   3. config/server.yml -- DEPRECATED, only for the handful of keys that used to
#      live there in plaintext. Reading one warns, once per key per process.
#
# The blank-ENV rule is the whole reason this exists: a blank
# `POSTMARK_API_TOKEN=` line in .env is truthy in Ruby, so it shadowed a
# perfectly good credential and 401'd every send for a day (Aug 2026). Every
# layer here passes through #normalize, so an empty value is never a value.
# #normalize also strips surrounding whitespace, so the trailing newline that
# Docker secrets, `systemd` EnvironmentFile and shell heredocs habitually add
# never reaches an API client.
#
# Not thread-safe by construction: the memoized resolver and its once-per-key
# warning list are written under a mutex, but a secret read during boot from
# several threads may still warn twice. Both deployments (Passenger's
# process-per-worker model, and the single-threaded Resque worker) resolve
# everything on the boot thread, so this has never mattered.
#
# Loaded with require_relative from config/application.rb (and ignored by the
# Zeitwerk autoloader there) because the environment files need it before the
# autoloaders are set up -- same precedent as lib/mailer_url_options.rb.
module AppSecrets
  # Raised by .fetch! when a secret is absent from every source.
  class MissingSecret < StandardError; end

  # Raised when a name is not registered below. A typo must never resolve to nil.
  class UnknownSecret < ArgumentError; end

  # name => { env: 'ENV_NAME', credentials: [path], server_yml: 'key' (deprecated) }
  REGISTRY = {
    secret_key_base: { env: 'SECRET_KEY_BASE', credentials: %i[secret_key_base] },
    stripe_secret_key: { env: 'STRIPE_SECRET_KEY', credentials: %i[stripe secret_key] },
    stripe_signing_secret: { env: 'STRIPE_SIGNING_SECRET', credentials: %i[stripe signing_secret] },
    postmark_api_token: { env: 'POSTMARK_API_TOKEN', credentials: %i[postmark_api_token] },
    my_emma_username: { env: 'MY_EMMA_USERNAME', credentials: %i[my_emma username] },
    my_emma_password: { env: 'MY_EMMA_PASSWORD', credentials: %i[my_emma password] },
    my_emma_account_id: { env: 'MY_EMMA_ACCOUNT_ID', credentials: %i[my_emma account_id] },
    paypal_login: { env: 'PAYPAL_LOGIN', credentials: %i[paypal login] },
    paypal_password: { env: 'PAYPAL_PASSWORD', credentials: %i[paypal password] },
    paypal_signature: { env: 'PAYPAL_SIGNATURE', credentials: %i[paypal signature] },
    paypal_pem_file: { env: 'PAYPAL_PEM_FILE', credentials: %i[paypal pem_file] },
    paypal_express_login: { env: 'PAYPAL_EXPRESS_LOGIN', credentials: %i[paypal_express login] },
    paypal_express_password: { env: 'PAYPAL_EXPRESS_PASSWORD', credentials: %i[paypal_express password] },
    resque_admin_password: { env: 'RESQUE_ADMIN_PASSWORD', credentials: %i[resque_admin_password],
                             server_yml: 'resque_admin_password' },
    aws_access_key_id: { env: 'AWS_ACCESS_KEY_ID', credentials: %i[aws access_key_id] },
    aws_secret_access_key: { env: 'AWS_SECRET_ACCESS_KEY', credentials: %i[aws secret_access_key] }
  }.freeze

  # Does the actual lookups. Everything it reads is injected, so specs can drive
  # it with plain hashes instead of the real ENV or a decrypted credentials file.
  # +credentials+ and +server_config+ may be objects or zero-arg callables; they
  # are called lazily because config.x.server_config is only assigned while the
  # environment file runs, which is after this class is loaded.
  class Resolver
    def initialize(env: ENV, credentials: nil, server_config: nil, registry: REGISTRY)
      @env = env
      @credentials = credentials
      @server_config = server_config
      @registry = registry
      @warned = []
    end

    # The secret, or nil when no source supplies a non-blank value.
    def [](name)
      entry = entry_for(name)
      from_env(entry) || from_credentials(entry) || from_server_yml(name, entry)
    end

    # The secret, or MissingSecret naming both places it can be put.
    def fetch!(name)
      self[name] || raise(MissingSecret, missing_message(name))
    end

    # :env, :credentials, :server_yml or :none.
    def source(name)
      entry = entry_for(name)
      return :env if from_env(entry)
      return :credentials if from_credentials(entry)
      return :server_yml if from_server_yml(name, entry)

      :none
    end

    # True when the ENV var exists but holds only whitespace -- i.e. the line
    # that silently shadows nothing today but would shadow a real secret the
    # moment someone types a character into it.
    def blank_env?(name)
      raw = @env[entry_for(name)[:env]]
      !raw.nil? && normalize(raw).nil?
    end

    # Where each secret is coming from, with no values in it -- safe to log or
    # print from `rake setup:doctor`.
    #
    # Carries one extra entry, :credentials_status, in the same shape as the
    # secrets so callers can iterate the whole hash uniformly; its :source is the
    # status symbol (see #credentials_status).
    def report
      @registry.keys.index_with do |name|
        { source: source(name), blank_env: blank_env?(name),
          env: @registry[name][:env], credentials: credentials_path(name) }
      end.merge(credentials_status: { source: credentials_status, blank_env: false,
                                      env: 'RAILS_MASTER_KEY', credentials: credentials_file })
    end

    # Can the encrypted credentials actually be read?
    #
    #   :ok          -- file present and a decryption key was found
    #   :no_key      -- file present, no key: EncryptedConfiguration#read rescues
    #                   MissingContentError and hands back {}, so EVERY credential
    #                   silently reads as nil. This is the failure that makes
    #                   "add the credential" advice maddening: it is already there.
    #   :absent      -- no credentials file at all (ENV-only deployment)
    #   :unavailable -- not a credentials object (specs inject plain hashes)
    def credentials_status
      store = resolve(@credentials)
      return :unavailable unless store.respond_to?(:content_path) && store.respond_to?(:key)
      return :absent unless store.content_path.exist?

      decryption_key(store).nil? ? :no_key : :ok
    end

    # Path of the credentials file in play, for messages.
    def credentials_file
      store = resolve(@credentials)
      return nil unless store.respond_to?(:content_path)

      relative_to_root(store.content_path)
    end

    # Dotted credentials path, e.g. "stripe.secret_key".
    def credentials_path(name)
      Array(entry_for(name)[:credentials]).join('.')
    end

    # The environment variable that supplies this secret.
    def env_name(name)
      entry_for(name)[:env]
    end

    def missing_message(name)
      entry = entry_for(name)
      "Missing secret #{name}: set ENV['#{entry[:env]}'] or add `#{credentials_path(name)}` " \
        'to the encrypted credentials (bin/rails credentials:edit).'
    end

    private

    # #key returns nil when no key is configured, but raises MissingKeyError
    # instead when require_master_key is on. Both mean "no key".
    def decryption_key(store)
      store.key
    rescue StandardError
      nil
    end

    def relative_to_root(path)
      path.relative_path_from(Rails.root).to_s
    rescue StandardError
      path.to_s
    end

    def entry_for(name)
      @registry.fetch(name.to_sym) do
        raise UnknownSecret, "Unknown secret #{name.inspect}. Known secrets: #{@registry.keys.join(', ')}"
      end
    end

    def from_env(entry)
      normalize(@env[entry[:env]])
    end

    def from_credentials(entry)
      path = Array(entry[:credentials])
      return nil if path.empty?

      store = resolve(@credentials)
      return nil if store.nil?

      # A wrong master key must stay loud, so ActiveSupport::MessageEncryptor::InvalidMessage
      # is deliberately not rescued. The TypeError guard is wrapped tightly
      # around the lookup itself and only covers a credential whose shape has
      # drifted (a scalar where a nested hash is expected).
      value = begin
        store.dig(*path)
      rescue TypeError
        nil
      end
      normalize(value)
    end

    def from_server_yml(name, entry)
      key = entry[:server_yml]
      return nil if key.nil?

      config = resolve(@server_config)
      return nil unless config.respond_to?(:[])

      value = normalize(config[key]) || normalize(config[key.to_sym])
      return nil if value.nil?

      warn_deprecated(name, key)
      value
    end

    def resolve(source)
      source.respond_to?(:call) ? source.call : source
    end

    def normalize(value)
      string = value.to_s.strip
      string.empty? ? nil : string
    end

    def warn_deprecated(name, key)
      return if @warned.include?(name)

      @warned << name
      message = "[AppSecrets] DEPRECATED: `#{key}` was read from config/server.yml. " \
                "Move it to ENV['#{entry_for(name)[:env]}'] or to credentials as " \
                "`#{credentials_path(name)}`; the server.yml fallback will be removed."
      # Not on stderr under test: Theater Wit's own server.yml carries the key in
      # its test: block, so every rspec and cucumber boot would print this. The
      # log line stays, and spec/lib/app_secrets_spec.rb asserts the warning.
      Kernel.warn(message) unless defined?(Rails) && Rails.respond_to?(:env) && Rails.env.test?
      Rails.logger.warn(message) if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
    end
  end

  MONITOR = Mutex.new
  private_constant :MONITOR

  class << self
    delegate :[], :fetch!, :source, :blank_env?, :report, :env_name, :credentials_path,
             :missing_message, :credentials_status, :credentials_file, to: :default_resolver

    # Drops the memoized resolver: re-reads ENV and re-arms the once-per-key
    # deprecation warnings. For specs and for `rake setup:*` tasks that rewrite .env.
    def reset!
      MONITOR.synchronize { @default_resolver = nil }
    end

    def default_resolver
      @default_resolver || MONITOR.synchronize do
        @default_resolver ||= Resolver.new(
          env: ENV,
          credentials: -> { Rails.application.credentials },
          server_config: -> { Rails.configuration.x.server_config }
        )
      end
    end
  end
end
