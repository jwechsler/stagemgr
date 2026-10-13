# frozen_string_literal: true

require 'net/http'
require 'json'

module Lgl
  # Thin REST client for the Little Green Light API (constituents and their
  # street address / phone entries).
  #
  # GET, POST and PATCH only: there is deliberately no way to delete anything
  # in LGL from Stagemgr. Every write consults Lgl.writable?(for_address_id)
  # and skips (with a logged warning) when the environment is read-only for
  # that address. Reads always run.
  #
  # Street and phone changes go through LGL's per-entry endpoints
  # (PATCH /street_addresses/{id}, POST /constituents/{id}/street_addresses and
  # the phone_numbers equivalents), so a write touches exactly one entry and
  # never the constituent's other entries.
  #
  # +http+ is injectable for specs: ->(Net::HTTPRequest, URI) { response }
  # where the response answers #code and #body.
  class Client
    BASE_URL = 'https://api.littlegreenlight.com/api/v1'
    OPEN_TIMEOUT_SECONDS = 10
    READ_TIMEOUT_SECONDS = 30
    # LGL allows 300 requests per 5 minutes; one per second keeps us well under.
    MIN_INTERVAL_SECONDS = 1.0
    PAGE_LIMIT = 1000
    SEARCH_PATH = '/constituents/search'
    CONSTITUENTS_PATH = '/constituents'
    STREET_ADDRESSES_PATH = '/street_addresses'
    PHONE_NUMBERS_PATH = '/phone_numbers'
    # LGL's "Home" type for street address and phone entries.
    HOME_STREET_ADDRESS_TYPE_ID = 1
    HOME_PHONE_NUMBER_TYPE_ID = 1
    HTTP_NOT_FOUND = 404
    HTTP_TOO_MANY_REQUESTS = 429

    def initialize(api_key:, http: nil, min_interval: MIN_INTERVAL_SECONDS)
      raise ArgumentError, 'LGL api_key is blank' if api_key.to_s.strip.empty?

      @api_key = api_key.to_s.strip
      @http = http || method(:net_http_request)
      @min_interval = min_interval.to_f
      @last_request_at = nil
    end

    # The constituent hash, or nil when LGL answers 404 (deleted or merged away).
    # No query params: LGL answers 403 Forbidden to this endpoint when any
    # `expand` is present, yet the plain response already includes
    # email_addresses, street_addresses and phone_numbers.
    def find(id)
      get("#{CONSTITUENTS_PATH}/#{Integer(id)}.json", [])
    rescue Error => e
      raise unless e.status == HTTP_NOT_FOUND

      nil
    end

    # Exact match on LGL's external_constituent_id (= Stagemgr address id).
    def search_by_external_id(address_id)
      search_page([['q[]', "external_id=eq|#{Integer(address_id)}"]]).fetch('items', [])
    end

    # LGL's eaddr search is a substring match, so the results are narrowed to
    # constituents that carry exactly this address (case-insensitive).
    def search_by_email(email)
      wanted = email.to_s.strip.downcase
      return [] if wanted.empty?

      items = search_page([['q[]', "eaddr=#{wanted}"], ['expand', 'email_addresses']]).fetch('items', [])
      items.select { |constituent| email_matches?(constituent, wanted) }
    end

    # Every constituent updated at or after +time+, oldest change first, across
    # all pages. Returns an Enumerator without a block.
    def search_updated_since(time, &block)
      return enum_for(:search_updated_since, time) unless block

      params = [['q[]', "updated_from=#{time.utc.iso8601}"], %w[sort date_updated],
                ['expand', 'email_addresses']]
      each_page(SEARCH_PATH, params) { |page| page.fetch('items', []).each(&block) }
    end

    # Every constituent in the account as a full hash, across all pages.
    # Returns an Enumerator without a block.
    def each_constituent(&block)
      return enum_for(:each_constituent) unless block

      each_page(CONSTITUENTS_PATH, []) { |page| page.fetch('items', []).each(&block) }
    end

    # [ids, total_items] for the whole account. The caller compares the two
    # before trusting the list as complete.
    def each_constituent_id
      ids = []
      total = nil
      each_page(CONSTITUENTS_PATH, []) do |page|
        total = page['total_items']
        ids.concat(page.fetch('items', []).pluck('id'))
      end
      [ids, total]
    end

    # One cheap authenticated request, for the setup doctor. Raises on failure.
    def ping
      get(CONSTITUENTS_PATH, [['limit', 1]])
    end

    def create(attrs, for_address_id:)
      write(Net::HTTP::Post, CONSTITUENTS_PATH, attrs, for_address_id)
    end

    def update(id, attrs, for_address_id:)
      write(Net::HTTP::Patch, "#{CONSTITUENTS_PATH}/#{Integer(id)}", attrs, for_address_id)
    end

    # Edits one existing street address entry in place.
    def update_street_address(id, attrs, for_address_id:)
      write(Net::HTTP::Patch, "#{STREET_ADDRESSES_PATH}/#{Integer(id)}", attrs, for_address_id)
    end

    # Adds a street address entry to the constituent.
    def add_street_address(constituent_id, attrs, for_address_id:)
      write(Net::HTTP::Post, "#{CONSTITUENTS_PATH}/#{Integer(constituent_id)}#{STREET_ADDRESSES_PATH}",
            attrs, for_address_id)
    end

    # Edits one existing phone number entry in place.
    def update_phone_number(id, attrs, for_address_id:)
      write(Net::HTTP::Patch, "#{PHONE_NUMBERS_PATH}/#{Integer(id)}", attrs, for_address_id)
    end

    # Adds a phone number entry to the constituent.
    def add_phone_number(constituent_id, attrs, for_address_id:)
      write(Net::HTTP::Post, "#{CONSTITUENTS_PATH}/#{Integer(constituent_id)}#{PHONE_NUMBERS_PATH}",
            attrs, for_address_id)
    end

    private

    def write(verb_class, path, attrs, address_id)
      return skipped(verb_class::METHOD, path, address_id) unless Lgl.writable?(address_id)

      request(verb_class, path, [], attrs)
    end

    def search_page(params)
      get(SEARCH_PATH, params + [['limit', PAGE_LIMIT]])
    end

    def each_page(path, params)
      offset = 0
      loop do
        page = get(path, params + [['limit', PAGE_LIMIT], ['offset', offset]])
        yield page
        next_offset = next_offset_for(page, offset)
        break if next_offset.nil?

        offset = next_offset
      end
    end

    def next_offset_for(page, offset)
      items = page.fetch('items', [])
      return nil if items.empty?

      next_item = page['next_item'].to_i
      return nil unless next_item > offset

      total = page['total_items']
      return nil if total && next_item >= total.to_i

      next_item
    end

    def email_matches?(constituent, wanted)
      Array(constituent['email_addresses']).any? do |entry|
        entry['address'].to_s.strip.downcase == wanted
      end
    end

    def skipped(verb, path, address_id)
      Rails.logger.warn("[LGL] read-only: skipped #{verb} #{path} for address ##{address_id}")
      nil
    end

    def get(path, params)
      request(Net::HTTP::Get, path, params)
    end

    def request(verb_class, path, params, payload = nil)
      uri = build_uri(path, params)
      req = verb_class.new(uri)
      req['Authorization'] = "Bearer #{@api_key}"
      req['Accept'] = 'application/json'
      if payload
        req['Content-Type'] = 'application/json'
        req.body = JSON.generate(payload)
      end
      throttle
      handle(@http.call(req, uri))
    end

    def build_uri(path, params)
      uri = URI("#{BASE_URL}#{path}")
      uri.query = URI.encode_www_form(params) unless params.empty?
      uri
    end

    def handle(response)
      status = response.code.to_i
      body = response.body.to_s
      raise RateLimited.new(status: status, body: body) if status == HTTP_TOO_MANY_REQUESTS
      raise Error.new(status: status, body: body) unless (200..299).cover?(status)

      body.strip.empty? ? {} : JSON.parse(body)
    rescue JSON::ParserError => e
      raise Error.new("LGL returned unparseable JSON (#{e.class})", status: status, body: body)
    end

    def throttle
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      if @last_request_at && @min_interval.positive?
        wait = @min_interval - (now - @last_request_at)
        sleep(wait) if wait.positive?
      end
      @last_request_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def net_http_request(req, uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                          open_timeout: OPEN_TIMEOUT_SECONDS,
                                          read_timeout: READ_TIMEOUT_SECONDS) do |http|
        http.request(req)
      end
    end
  end
end
