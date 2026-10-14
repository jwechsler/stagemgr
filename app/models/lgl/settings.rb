# frozen_string_literal: true

module Lgl
  # The `littlegreenlight:` section of config/server.yml, with ENV overrides.
  #
  #   littlegreenlight:
  #     sync: enabled                # anything else (or missing) = disabled; ENV LGL_SYNC
  #     writable_address_ids: 12, 34 # or a YAML list; ENV LGL_WRITABLE_ADDRESS_IDS
  #     web_url: https://youraccount.littlegreenlight.com
  #
  # Same rule as AppSecrets: a non-blank ENV value wins, a blank one counts as
  # absent. The API key is a secret and never comes from here (AppSecrets).
  # Everything is injected so specs drive it with plain hashes.
  class Settings
    SECTION = 'littlegreenlight'
    SYNC_ENV = 'LGL_SYNC'
    WRITABLE_ENV = 'LGL_WRITABLE_ADDRESS_IDS'
    ENABLED = 'enabled'
    ID_PATTERN = /\A\d+\z/

    # Set of Integer, or nil when no allowlist is configured. A non-blank value
    # with no valid id gives an empty Set: read-only for everyone, never wide open.
    attr_reader :writable_address_ids, :web_url
    # :env, :server_yml or :none
    attr_reader :sync_source, :writable_address_ids_source

    def self.from(server_config, env: ENV)
      section = server_config.respond_to?(:[]) ? (server_config[SECTION] || server_config[SECTION.to_sym]) : nil
      section = {} unless section.respond_to?(:[])
      new(
        sync: pick(env[SYNC_ENV], value_in(section, 'sync')),
        writable: pick(env[WRITABLE_ENV], value_in(section, 'writable_address_ids')),
        web_url: value_in(section, 'web_url')
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

    def initialize(sync:, writable:, web_url:)
      sync_value, @sync_source = sync
      ids_value, @writable_address_ids_source = writable
      @sync_enabled = sync_value.to_s.strip.casecmp?(ENABLED)
      @writable_address_ids = ids_value.nil? ? nil : parse_ids(ids_value)
      @web_url = web_url.to_s.strip.chomp('/').presence
      freeze
    end

    def sync_enabled?
      @sync_enabled
    end

    private

    def parse_ids(value)
      list = value.is_a?(Array) ? value : value.to_s.split(',')
      list.map { |id| id.to_s.strip }.grep(ID_PATTERN).map(&:to_i).select(&:positive?).to_set.freeze
    end
  end
end
