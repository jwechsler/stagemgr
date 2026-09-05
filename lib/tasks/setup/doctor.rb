# frozen_string_literal: true

module Setup
  # Pre-flight check for an installed checkout: is the configuration complete
  # enough for this process to serve traffic?
  #
  # Reports rather than fixes. `rake setup:doctor` exits non-zero when anything
  # is broken, which is what makes it usable as a deploy gate (bin/deploy runs
  # it between migrate and precompile, and bin/docker-entrypoint gates a
  # production boot on it) and as the first thing to run when a fresh install
  # misbehaves.
  #
  # Severity depends on the environment: a missing Stripe key is fatal in
  # production and merely worth mentioning in development, where nobody is
  # taking payments yet. Anything that would break *this* environment — an
  # unresolvable layout, an unreachable database — is fatal everywhere.
  #
  # Needs a booted app (the rake task depends on :environment).
  class Doctor
    OK = :ok
    WARN = :warn
    FAIL = :fail

    MARKS = { OK => '  ok  ', WARN => ' warn ', FAIL => ' FAIL ' }.freeze

    # Anything that looks like credentials in a URL's userinfo section.
    DSN_USERINFO = %r{(?<scheme>[a-z][a-z0-9+.-]*://)(?<userinfo>[^/@\s]+)@}i

    def initialize(out: $stdout)
      @out = out
      @results = []
    end

    # Runs every check, printing as it goes. Ask #healthy? for the verdict.
    def run
      @results.clear
      check_server_yml
      check_site_theme
      check_site_wrapper_layout
      check_credentials_store
      check_secrets
      check_required_secrets
      check_database
      check_redis
      summarize
      self
    end

    def healthy?
      @results.none? { |severity, _| severity == FAIL }
    end

    # Strips the userinfo from a DSN so a password never reaches the terminal or
    # a CI log. redis://user:pw@host/0 -> redis://***@host/0
    def self.redact(dsn)
      dsn.to_s.gsub(DSN_USERINFO) { "#{Regexp.last_match[:scheme]}***@" }
    end

    private

    def server_config
      Rails.configuration.x.server_config || {}
    end

    # Secrets are only load-bearing for the environment that actually serves
    # patrons. Elsewhere they are advisory (plan A4: prod rules under
    # RAILS_ENV=production).
    def secret_severity
      Rails.env.production? ? FAIL : WARN
    end

    def check_server_yml
      path = Rails.root.join('config/server.yml')
      if path.exist?
        record OK, "config/server.yml present (#{server_config.keys.size} keys merged for #{Rails.env})"
      else
        record FAIL, 'config/server.yml is missing — run `bundle exec rake setup:config`'
      end
    end

    def check_site_theme
      slug = server_config['site_theme'].presence
      return record OK, 'site_theme not set — the generic (unthemed) views are in use' if slug.nil?

      views = Rails.root.join('sites', slug, 'views')
      if views.directory?
        record OK, "site theme '#{slug}' found at sites/#{slug}/views"
      else
        record FAIL, "server.yml sets site_theme: #{slug} but sites/#{slug}/views does not exist — " \
                     "run `bundle exec rake setup:site[#{slug}]` or clear the key"
      end
    end

    def check_site_wrapper_layout
      layout = server_config['ext_site_wrapper'].presence
      return record WARN, 'server.yml has no ext_site_wrapper — public pages will use the default layout' if layout.nil?

      if ApplicationController.new.lookup_context.exists?(layout, ['layouts'])
        record OK, "public layout '#{layout}' resolves"
      else
        record FAIL, "server.yml sets ext_site_wrapper: #{layout} but no layouts/#{layout} template resolves — " \
                     'every public page will 500 (standalone installs want `standalone`)'
      end
    end

    # Checked before the per-secret inventory because it explains it: with the
    # file present and no key, every single credential reads as missing and the
    # advice "add it to credentials" is maddening — it is already there.
    def check_credentials_store
      return record WARN, 'AppSecrets is not loaded — skipping the credentials check' unless defined?(AppSecrets)

      case AppSecrets.credentials_status
      when :ok
        record OK, "encrypted credentials readable (#{AppSecrets.credentials_file})"
      when :absent
        record OK, 'no encrypted credentials file — secrets come from the environment'
      when :no_key
        record FAIL, "#{AppSecrets.credentials_file} exists but no decryption key " \
                     "(config/credentials/#{AppSecrets.env_name}.key or RAILS_MASTER_KEY) — " \
                     'every credential reads as missing'
      else
        record WARN, 'credentials store not inspectable in this process'
      end
    end

    # Sources only, never values.
    def check_secrets
      return unless defined?(AppSecrets)

      report = AppSecrets.report.dup
      report.delete(:credentials_status) # reported by #check_credentials_store

      report.each do |name, info|
        if info[:blank_env]
          record WARN, "#{name}: ENV['#{info[:env]}'] is present but BLANK (ignored) — delete the line; " \
                       "resolved from #{info[:source]}"
        else
          record OK, "#{name}: #{info[:source]}"
        end
      end
    end

    def check_required_secrets
      unless defined?(RequiredSecrets)
        return record WARN, 'RequiredSecrets is not loaded — skipping the required-secrets check'
      end

      missing = RequiredSecrets.missing(server_config: server_config)
      if missing.empty?
        record OK, "all secrets required by this configuration are present (#{Rails.env})"
      else
        missing.each { |name| record secret_severity, RequiredSecrets.describe(name) }
      end

      RequiredSecrets.warn_only_missing(server_config: server_config).each do |name|
        record WARN, RequiredSecrets.describe(name)
      end
    end

    def check_database
      name = ActiveRecord::Base.connection_db_config.database
      ActiveRecord::Base.connection.select_value('SELECT 1')
      pending = ActiveRecord::Base.connection.migration_context.needs_migration?
      record OK, "database '#{name}' reachable"
      record FAIL, 'there are pending migrations — run `bundle exec rails db:migrate`' if pending
    rescue StandardError => e
      record FAIL, "database not reachable (#{e.class}: #{first_line(e.message)})"
    end

    def check_redis
      Resque.redis.ping
      record OK, "redis reachable at #{self.class.redact(redis_url)}"
    rescue StandardError => e
      record FAIL, "redis at #{self.class.redact(redis_url)} not reachable (#{e.class}: #{first_line(e.message)})"
    end

    def redis_url
      ENV['REDIS_URL'].presence || 'redis://localhost:6379'
    end

    # Exception messages can carry the whole DSN (and a stack of context);
    # keep one redacted line.
    def first_line(message)
      self.class.redact(message.to_s.lines.first.to_s.strip)
    end

    def record(severity, message)
      @results << [severity, message]
      @out.puts "[#{MARKS.fetch(severity)}] #{message}"
    end

    def summarize
      failures = @results.count { |severity, _| severity == FAIL }
      warnings = @results.count { |severity, _| severity == WARN }
      @out.puts
      @out.puts "setup:doctor: #{@results.size} checks, #{failures} failed, #{warnings} warning(s)."
    end
  end
end
