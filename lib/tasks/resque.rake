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
    redis_url = ENV["REDIS_URL"] || "redis://localhost:6379"
    redis = Redis.new(url: redis_url)

    # Create a namespaced Redis instance
    require 'redis/namespace'
    redis_namespace = Redis::Namespace.new("stagemgr:#{Rails.env}", redis: redis)

    # Set Redis connection for Resque
    Resque.redis = redis_namespace

    # If you want to be able to dynamically change the schedule,
    # uncomment this line.  A dynamic schedule can be updated via the
    # Resque::Scheduler.set_schedule (and remove_schedule) methods.
    # When dynamic is set to true, the scheduler process looks for
    # schedule changes and applies them on the fly.
    # Note: This feature is only available in >=2.0.0.
    # Resque::Scheduler.dynamic = true

    # The schedule doesn't need to be stored in a YAML, it just needs to
    # be a hash.  YAML is usually the easiest.
    Resque.schedule = YAML.load_file("#{::Rails.root.to_s}/config/schedule.yml")

    # If your schedule already has +queue+ set for each job, you don't
    # need to require your jobs.  This can be an advantage since it's
    # less code that resque-scheduler needs to know about. But in a small
    # project, it's usually easier to just include you job classes here.
    # So, something like this:
    # require 'resque_jobs'
  end
end
