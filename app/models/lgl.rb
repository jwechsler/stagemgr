# frozen_string_literal: true

# Little Green Light (donor CRM) integration switchboard, modelled on MyEmma.
#
# Each environment's after_initialize calls Lgl.configure_from with the
# `littlegreenlight:` settings (Lgl::Settings) and the API key (AppSecrets);
# the test environment calls Lgl.disable. `littlegreenlight.sync` picks the
# mode: disabled (every caller short-circuits on Lgl.enabled?), readonly
# (reads hit the live account, every write is skipped and logged unless the
# address is in writable_address_ids) or enabled (reads and writes). The guard
# is enforced inside Lgl::Client#create / #update, so a caller cannot forget it.
module Lgl
  # Any non-2xx answer from LGL (other than a 404 on #find).
  class Error < StandardError
    attr_reader :status, :body

    def initialize(message = nil, status: nil, body: nil)
      @status = status
      @body = body
      super(message || "LGL request failed (HTTP #{status})")
    end
  end

  # HTTP 429: LGL allows 300 requests per 5 minutes.
  class RateLimited < Error; end

  # Why every LGL entry point is a no-op while Lgl.enabled? is false.
  DISABLED_MESSAGE = 'LGL sync is disabled: it needs littlegreenlight.sync: enabled or readonly ' \
                     '(or LGL_SYNC) and LGL_API_KEY'

  class << self
    # The one place the mode rules live:
    #
    #   * test, sync disabled, or no key      -> disabled
    #   * sync readonly                       -> read-only except writable_address_ids
    #   * sync enabled, development           -> downgraded to readonly (logged), so a
    #                                            copied config never writes live LGL
    #   * sync enabled, any other environment -> fully writable; the allowlist is ignored
    def configure_from(settings, api_key:, environment:)
      @settings = settings
      environment = environment.to_s
      return disable.read_write! if environment == 'test' || !settings.sync_enabled? || api_key.to_s.strip.empty?

      configure(api_key)
      if settings.read_only_mode? || environment == 'development'
        log_development_downgrade unless settings.read_only_mode?
        read_only!(except_address_ids: settings.writable_address_ids)
      else
        read_write!
      end
    end

    # The settings the environment was configured from, or (when nothing called
    # configure_from, e.g. under test) the ones config/server.yml and ENV give now.
    def settings
      @settings || Lgl::Settings.from(Rails.configuration.x.server_config)
    end

    # Back to the boot state of the test environment. For specs.
    def reset!
      @settings = nil
      read_write!
      disable
    end

    def configure(api_key)
      @api_key = api_key.to_s.strip.presence
      @client = nil
      self
    end

    def disable
      @api_key = nil
      @client = nil
      self
    end

    # The single switch every LGL job, trigger, page and task checks.
    def enabled?
      @api_key.present?
    end

    # One info line for a job that found LGL disabled when it ran (e.g. queued
    # before sync was turned off). Returns nil.
    def log_disabled(what)
      Rails.logger.info("[LGL] #{what} skipped: #{DISABLED_MESSAGE}")
      nil
    end

    # +except_address_ids+: comma-separated string, array or Set of Stagemgr
    # address ids that may still be written to LGL (see Lgl::Settings.parse_ids).
    def read_only!(except_address_ids: nil)
      @read_only = true
      @writable_address_ids = Lgl::Settings.parse_ids(except_address_ids)
      self
    end

    def read_write!
      @read_only = false
      @writable_address_ids = Set.new
      self
    end

    def read_only?
      @read_only == true
    end

    def writable?(address_id)
      return false unless enabled?
      return true unless read_only?

      writable_address_ids.include?(address_id.to_i)
    end

    def writable_address_ids
      @writable_address_ids || Set.new
    end

    def client
      raise Error, 'LGL is not configured' unless enabled?

      @client ||= Lgl::Client.new(api_key: @api_key)
    end

    # The constituent's page in this house's LGL account, or nil when
    # `littlegreenlight: web_url:` is not set in config/server.yml (each
    # account has its own subdomain, so there is no safe default).
    def constituent_url(id)
      base = Lgl::Settings.from(Rails.configuration.x.server_config, env: {}).web_url
      return nil if base.nil? || id.blank?

      "#{base}/constituents/#{ERB::Util.url_encode(id.to_s)}"
    end

    private

    def log_development_downgrade
      Rails.logger.info("[LGL] sync 'enabled' downgraded to readonly in development")
    end
  end
end
