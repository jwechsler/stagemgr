# frozen_string_literal: true

require 'net/http'

module Lgl
  # Downloads the CSV behind an LGL saved report's permanent link and checks it
  # looks like a donor-tier export before anyone imports it.
  #
  # HTTP Basic auth is sent only when both the user and password are set. One
  # redirect is followed (LGL may hand off to signed storage); credentials go
  # along only when the redirect stays on the same scheme and host.
  #
  # Every failure raises Lgl::Error. The report link can carry a secret token in
  # its query string, so messages and log lines name the host and never the
  # URL or the user name.
  class DonorLevelsDownload
    MAX_BYTES = 20.megabytes
    CONTENT_TYPES = %w[text/csv application/csv text/plain application/octet-stream].freeze
    AUTH_FAILURE_STATUSES = [401, 403].freeze
    AUTH_HINT = 'check LGL_USER / LGL_PASSWORD'
    LINK_HINT = "check the report's permanent link"
    UTF8_BOM = "﻿"
    NETWORK_ERRORS = [SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError].freeze

    def self.fetch(url, user: AppSecrets[:lgl_user], password: AppSecrets[:lgl_password], http: nil)
      new(user: user, password: password, http: http).fetch(url)
    end

    def initialize(user:, password:, http: nil)
      @credentials = [user, password] if user.present? && password.present?
      @http = http || method(:net_http_request)
    end

    def fetch(url)
      uri = parse(url)
      response = get(uri, send_credentials: true)
      if response.is_a?(Net::HTTPRedirection)
        target = redirect_target(uri, response)
        response = get(target, send_credentials: same_origin?(uri, target))
        raise failure(target, 'redirected more than once', response) if response.is_a?(Net::HTTPRedirection)

        uri = target
      end
      body = validated_body(uri, response)
      Rails.logger.info("[LGL] donor levels report downloaded from #{uri.host} (#{body.bytesize} bytes)")
      body
    end

    private

    def parse(url)
      uri = URI.parse(url.to_s.strip)
      return uri if uri.is_a?(URI::HTTP) && uri.host.present?

      raise Error, 'Donor levels report link is not an http(s) URL'
    rescue URI::InvalidURIError
      raise Error, 'Donor levels report link is not a valid URL'
    end

    def get(uri, send_credentials:)
      request = Net::HTTP::Get.new(uri)
      request['Accept'] = 'text/csv'
      request.basic_auth(*@credentials) if send_credentials && @credentials
      @http.call(request, uri)
    rescue *NETWORK_ERRORS => e
      raise Error, "Donor levels report: could not reach #{uri.host} (#{e.class})"
    end

    def redirect_target(uri, response)
      location = response['Location']
      raise failure(uri, 'redirect without a Location', response) if location.blank?

      target = URI.join(uri, location)
      raise failure(uri, 'redirected to a non-http(s) location', response) unless target.is_a?(URI::HTTP)

      target
    rescue URI::InvalidURIError
      raise failure(uri, 'redirected to an invalid location', response)
    end

    def same_origin?(uri, target)
      uri.scheme == target.scheme && uri.host.casecmp?(target.host.to_s)
    end

    def validated_body(uri, response)
      status = response.code.to_i
      raise failure(uri, status_problem(status), response) unless (200..299).cover?(status)

      check_size(uri, response)
      check_content_type(uri, response)
      body = response.body.to_s.dup.force_encoding(Encoding::UTF_8)
      raise failure(uri, 'the report is empty', response) if body.strip.empty?

      check_headers(uri, response, body)
      body
    end

    def status_problem(status)
      hint = AUTH_FAILURE_STATUSES.include?(status) ? AUTH_HINT : LINK_HINT
      "unexpected response; #{hint}"
    end

    def check_size(uri, response)
      declared = response['Content-Length'].to_i
      return unless declared > MAX_BYTES || response.body.to_s.bytesize > MAX_BYTES

      raise failure(uri, "the report is larger than #{MAX_BYTES / 1.megabyte} MB", response)
    end

    def check_content_type(uri, response)
      type = response['Content-Type'].to_s.strip.downcase
      return if CONTENT_TYPES.any? { |allowed| type.start_with?(allowed) }

      raise failure(uri, "unexpected content type #{type.presence || '(none)'}; is the link a CSV export?", response)
    end

    def check_headers(uri, response, body)
      header_line = body.each_line.first.to_s.scrub.delete_prefix(UTF8_BOM).strip.downcase
      missing = LglDonorImport::REQUIRED_HEADERS.reject { |name| header_line.include?(name.downcase) }
      return if missing.empty?

      raise failure(uri, "the report is missing column #{missing.join(', ')}", response)
    end

    def failure(uri, problem, response)
      status = response.code.to_i
      Error.new("Donor levels report from #{uri.host} (HTTP #{status}): #{problem}", status: status)
    end

    def net_http_request(request, uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                          open_timeout: Client::OPEN_TIMEOUT_SECONDS,
                                          read_timeout: Client::READ_TIMEOUT_SECONDS) do |http|
        http.request(request)
      end
    end
  end
end
