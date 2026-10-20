# frozen_string_literal: true

module Lgl
  # The `littlegreenlight:` section of config/server.yml, with ENV overrides.
  #
  #   littlegreenlight:
  #     sync: readonly               # enabled | readonly | disabled (any other word or
  #                                  # missing = disabled); ENV LGL_SYNC
  #     writable_address_ids: 12, 34 # or a YAML list; only used in readonly mode;
  #                                  # ENV LGL_WRITABLE_ADDRESS_IDS
  #     web_url: https://youraccount.littlegreenlight.com
  #     donor_tier_report_url: https://...  # ENV LGL_DONOR_TIER_REPORT_URL
  #     donor_flag_excluded_tiers: ["Up to $99.99"]  # or one label; no ENV override
  #
  # sync_mode is :enabled (reads and writes), :readonly (reads; writes skipped
  # except writable_address_ids) or :disabled. Lgl.configure_from turns the
  # mode into the running state (and downgrades enabled to readonly in
  # development).
  #
  # Same rule as AppSecrets: a non-blank ENV value wins, a blank one counts as
  # absent. The API key is a secret and never comes from here (AppSecrets).
  # Everything is injected so specs drive it with plain hashes.
  class Settings
    SECTION = 'littlegreenlight'
    SYNC_ENV = 'LGL_SYNC'
    WRITABLE_ENV = 'LGL_WRITABLE_ADDRESS_IDS'
    DONOR_TIER_REPORT_URL_ENV = 'LGL_DONOR_TIER_REPORT_URL'
    SYNC_MODES = %i[enabled readonly disabled].freeze
    ID_PATTERN = /\A\d+\z/

    # Set of Integer, or nil when no allowlist is configured. A non-blank value
    # with no valid id gives an empty Set: read-only for everyone, never wide open.
    attr_reader :writable_address_ids, :web_url
    # The configured sync word, stripped and downcased; nil when not set.
    attr_reader :sync_value
    # :enabled, :readonly or :disabled
    attr_reader :sync_mode
    # Permanent link of the LGL saved report imported as donor levels, or nil.
    attr_reader :donor_tier_report_url
    # Frozen Array of LGL donor tier labels that earn no heart icon on box office
    # receipts, in either the current or last fiscal year; [] when unset. Read whatever sync_mode is.
    attr_reader :donor_flag_excluded_tiers
    # :env, :server_yml or :none
    attr_reader :sync_source, :writable_address_ids_source, :donor_tier_report_url_source

    def self.from(server_config, env: ENV)
      section = server_config.respond_to?(:[]) ? (server_config[SECTION] || server_config[SECTION.to_sym]) : nil
      section = {} unless section.respond_to?(:[])
      new(
        sync: pick(env[SYNC_ENV], value_in(section, 'sync')),
        writable: pick(env[WRITABLE_ENV], value_in(section, 'writable_address_ids')),
        web_url: value_in(section, 'web_url'),
        donor_tier_report_url: pick(env[DONOR_TIER_REPORT_URL_ENV], value_in(section, 'donor_tier_report_url')),
        donor_flag_excluded_tiers: value_in(section, 'donor_flag_excluded_tiers')
      )
    end

    # [value, source] for the first non-blank of ENV and server.yml.
    def self.pick(env_value, yml_value)
      return [env_value, :env] unless blank_value?(env_value)
      return [yml_value, :server_yml] unless blank_value?(yml_value)

      [nil, :none]
    end

    def self.value_in(section, key)
      section[key].nil? ? section[key.to_sym] : section[key]
    end

    def self.blank_value?(value)
      return value.all? { |item| blank_value?(item) } if value.is_a?(Array)

      value.to_s.strip.empty?
    end
    private_class_method :pick, :value_in, :blank_value?

    # A frozen Set of positive address ids from a comma-separated String, an
    # Array or an already-parsed Set. Anything that is not all digits is dropped.
    def self.parse_ids(value)
      list = value.is_a?(Array) || value.is_a?(Set) ? value : value.to_s.split(',')
      list.map { |id| id.to_s.strip }.grep(ID_PATTERN).map(&:to_i).select(&:positive?).to_set.freeze
    end

    def initialize(sync:, writable:, web_url:, donor_tier_report_url:, donor_flag_excluded_tiers:)
      raw_sync, @sync_source = sync
      ids_value, @writable_address_ids_source = writable
      report_url, @donor_tier_report_url_source = donor_tier_report_url
      @sync_value = raw_sync.to_s.strip.downcase.presence
      @sync_mode = SYNC_MODES.find { |mode| mode.to_s == @sync_value } || :disabled
      @writable_address_ids = ids_value.nil? ? nil : self.class.parse_ids(ids_value)
      @web_url = web_url.to_s.strip.chomp('/').presence
      @donor_tier_report_url = report_url.to_s.strip.presence
      @donor_flag_excluded_tiers = parse_tiers(donor_flag_excluded_tiers)
      freeze
    end

    # True in enabled and readonly mode; existing callers rely on it.
    def sync_enabled?
      sync_mode != :disabled
    end

    def read_only_mode?
      sync_mode == :readonly
    end

    # False when sync is set to a word other than enabled, readonly or disabled.
    def sync_value_recognized?
      sync_value.nil? || SYNC_MODES.any? { |mode| mode.to_s == sync_value }
    end

    def donor_levels_enabled?
      !donor_tier_report_url.nil?
    end

    private

    # A YAML list or a single label; stripped, blanks dropped.
    def parse_tiers(value)
      Array(value).map { |tier| tier.to_s.strip }.reject(&:empty?).freeze
    end
  end
end
