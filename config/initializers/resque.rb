require 'resque/server'
require 'resque/scheduler'
require 'resque/scheduler/server'
require 'resque-retry'
require 'resque/failure/redis'
require 'resque-retry/server'

Resque::Failure::MultipleWithRetrySuppression.classes = [Resque::Failure::Redis]
Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression

# Set the Redis server for Resque
Resque.redis = ENV['REDIS_URL'] || 'redis://localhost:6379'

# Optionally set a namespace to prevent collisions
# Resque.redis.namespace = "resque:stagemgr"

class Stagemgr::Resque < Resque::Server
end

Resque::Scheduler.dynamic = true
Resque.schedule = YAML.load_file("#{::Rails.root.to_s}/config/schedule.yml")
