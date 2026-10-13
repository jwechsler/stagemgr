# frozen_string_literal: true

# Little Green Light (donor CRM) integration switchboard, modelled on MyEmma.
#
# Optional: with no API key the environment calls Lgl.disable and every caller
# short-circuits on Lgl.enabled?. Development calls Lgl.read_only!, which lets
# reads hit the live account but skips every write (logged) unless the address
# is listed in ENV['LGL_WRITABLE_ADDRESS_IDS']. The guard is enforced inside
# Lgl::Client#create / #update, so a caller cannot forget it.
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

  class << self
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

    def enabled?
      @api_key.present?
    end

    # +except_address_ids+: comma-separated string or array of Stagemgr
    # address ids that may still be written to LGL.
    def read_only!(except_address_ids: nil)
      @read_only = true
      @writable_address_ids = parse_ids(except_address_ids)
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

    private

    def parse_ids(value)
      list = value.is_a?(Array) ? value : value.to_s.split(',')
      list.map { |id| id.to_s.strip }.reject(&:empty?).map(&:to_i).select(&:positive?).to_set
    end
  end
end
