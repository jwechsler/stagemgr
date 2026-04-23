require 'rack/attack'

redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379'
Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
  url: redis_url,
  namespace: "stagemgr:#{Rails.env}:rack-attack",
  reconnect_attempts: 1,
  error_handler: ->(method:, returning:, exception:) {
    Rails.logger.warn("rack-attack cache error (#{method}): #{exception.class}: #{exception.message}")
  }
)

ASSET_PREFIXES = %w[/assets /packs /favicon].freeze
LOGIN_PATH_RE = %r{/(user_session|login)\z}.freeze
ORDER_PATH_RE = %r{/(ticket|donation|membership|flex_pass)_orders(\.|/|\z)}.freeze

Rack::Attack.throttle('req/ip', limit: 300, period: 5.minutes) do |req|
  req.ip unless ASSET_PREFIXES.any? { |p| req.path.include?(p) }
end

Rack::Attack.throttle('logins/ip', limit: 10, period: 1.minute) do |req|
  req.ip if req.post? && LOGIN_PATH_RE.match?(req.path)
end

Rack::Attack.throttle('orders-post/ip', limit: 30, period: 1.minute) do |req|
  req.ip if req.post? && ORDER_PATH_RE.match?(req.path)
end

Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env['rack.attack.match_data'] || {}
  now = match_data[:epoch_time] || Time.now.to_i
  retry_after = (match_data[:period] || 60).to_i

  headers = {
    'Content-Type' => 'text/plain',
    'Retry-After' => retry_after.to_s,
    'RateLimit-Limit' => match_data[:limit].to_s,
    'RateLimit-Remaining' => '0',
    'RateLimit-Reset' => (now + retry_after).to_s
  }
  [429, headers, ["Rate limit exceeded. Try again in #{retry_after} seconds.\n"]]
end

ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  Rails.logger.warn("[rack-attack] throttled matched=#{req.env['rack.attack.matched']} ip=#{req.ip} path=#{req.path}")
end
