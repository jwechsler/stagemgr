# Installation and first-run tasks.
#
# After cloning, the shortest path to a working install is:
#
#     bundle exec rake setup:config     # scaffold config/*.yml and .env
#     bundle exec rake setup:wizard     # database, admin, theater, keys, doctor
#
# The wizard is idempotent and every step it runs is also a task of its own, so
# you can re-run just the part you need. See docs/manual/developer/installation.md.
#
# The implementation lives in plain Ruby classes under lib/tasks/setup/ (which
# the Zeitwerk autoloader ignores, hence require_relative) so it can be unit
# tested against a temporary directory instead of the real checkout.

require_relative 'setup/scaffold'

namespace :setup do
  # Lambdas, not `def`s: a method defined inside a namespace block lands on
  # Object and would be callable from anywhere in the app.
  project_root = -> { File.expand_path('../..', __dir__) }
  scaffold = -> { Setup::Scaffold.new(root: project_root.call) }
  wizard = lambda do
    # Required lazily: wizard.rb references Rails constants, and setup:config
    # has to work before the app can boot.
    require_relative 'setup/wizard'
    Setup::Wizard.new
  end

  # Deliberately NOT dependent on :environment: this task generates
  # config/database.yml and config/server.yml, both of which Rails needs before
  # it can boot. bin/docker-entrypoint runs it on every container start.
  desc 'Scaffold config/*.yml and .env from their .example templates (never overwrites)'
  task :config do # rubocop:disable Rails/RakeEnvironment
    scaffold.call.config
  end

  desc 'Copy sites/example to sites/SLUG and point server.yml at it — rake setup:site[mytheater]'
  task :site, [:slug] do |_task, args| # rubocop:disable Rails/RakeEnvironment
    slug = args[:slug].to_s
    abort 'Usage: rake setup:site[slug]' if slug.empty?

    begin
      scaffold.call.site(slug)
    rescue Setup::Scaffold::Error => e
      abort "setup:site: #{e.message}"
    end
  end

  desc 'Generate SECRET_KEY_BASE in .env if it is blank or missing'
  task :secret_key_base do # rubocop:disable Rails/RakeEnvironment
    scaffold.call.secret_key_base
  end

  desc 'Prepare the database (create, load db/schema.rb, migrate, seed when empty)'
  task bootstrap: :environment do
    wizard.call.bootstrap
  end

  desc 'Create or update the first administrator (ADMIN_EMAIL/ADMIN_PASSWORD skip the prompts)'
  task admin: :environment do
    wizard.call.admin
  end

  desc 'Create the first theater and venue and associate the administrator'
  task theater: :environment do
    wizard.call.theater
  end

  desc 'Prompt for Stripe keys and write them to .env'
  task payments: :environment do
    wizard.call.payments
  end

  desc 'Create one sample production with performances, ticket classes and allocations'
  task demo_data: :environment do
    wizard.call.demo_data
  end

  desc 'Check that this install is configured well enough to serve traffic (exits 1 on problems)'
  task doctor: :environment do
    require_relative 'setup/doctor'
    exit 1 unless Setup::Doctor.new.run.healthy?
  end

  desc 'Interactive end-to-end first-run setup'
  task wizard: :environment do
    wizard.call.run
  end
end

namespace :config do
  desc 'DEPRECATED alias for setup:config'
  task :setup do # rubocop:disable Rails/RakeEnvironment
    warn 'config:setup is deprecated and will be removed; use `rake setup:config` instead.'
    Rake::Task['setup:config'].invoke
  end
end
