require 'resque/server'
require 'resque/scheduler'
require 'resque/scheduler/server'
require 'resque-retry'
require 'resque/failure/redis'
require 'resque-retry/server'
require 'redis'

Resque::Failure::MultipleWithRetrySuppression.classes = [Resque::Failure::Redis]
Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression

# Set the Redis server for Resque with production-ready configuration
redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379'
redis = Redis.new(
  url: redis_url,
  timeout: 5.0,               # Connection timeout in seconds
  reconnect_attempts: 3,      # Number of reconnection attempts
  reconnect_delay: 0.5,       # Delay between reconnection attempts in seconds
  connect_timeout: 5.0,       # Timeout for initial connection
  read_timeout: 5.0,          # Timeout for read operations
  write_timeout: 5.0          # Timeout for write operations
)

# Create a namespaced Redis instance
require 'redis/namespace'
redis_namespace = Redis::Namespace.new("stagemgr:#{Rails.env}", redis: redis)

# Set Redis connection for Resque
Resque.redis = redis_namespace

class Stagemgr::Resque < Resque::Server
end

Resque::Scheduler.dynamic = true
Resque.schedule = YAML.load_file(Rails.root.join('config/schedule.yml').to_s)
