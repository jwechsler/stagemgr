require 'resque/tasks'
require 'resque/scheduler/tasks'

# require 'resque/tasks'
# require 'resque_scheduler/tasks'
#
# require 'resque_jobs/age_out_file_store'

namespace :resque do
  task :setup do
    require 'resque'
    require 'resque/scheduler'
    require 'resque-retry'
    require 'resque/failure/redis'

    # Connect to Redis using the same method as in initializers/resque.rb
    redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379'
    redis = Redis.new(url: redis_url)

    # Create a namespaced Redis instance
    require 'redis/namespace'
    redis_namespace = Redis::Namespace.new("stagemgr:#{Rails.env}", redis: redis)

    # Set Redis connection for Resque
    Resque.redis = redis_namespace

    # Dynamic schedule mode must stay off; see the comment above
    # Resque.schedule= in config/initializers/resque.rb for why. If runtime
    # schedule edits (Resque.set_schedule / remove_schedule) are ever wanted,
    # first guard the initializer's Resque.schedule= load so only the
    # scheduler process runs it, or every Rails boot will restart every
    # `every:` interval.

    # The schedule doesn't need to be stored in a YAML, it just needs to
    # be a hash.  YAML is usually the easiest.
    Resque.schedule = YAML.load_file(Rails.root.join('config/schedule.yml').to_s)

    # If your schedule already has +queue+ set for each job, you don't
    # need to require your jobs.  This can be an advantage since it's
    # less code that resque-scheduler needs to know about. But in a small
    # project, it's usually easier to just include you job classes here.
    # So, something like this:
    # require 'resque_jobs'
  end
end
