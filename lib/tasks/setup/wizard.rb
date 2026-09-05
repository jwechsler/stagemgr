# frozen_string_literal: true

require 'io/console'
require_relative 'env_file'
require_relative 'scaffold'
require_relative 'doctor'

module Setup
  # Interactive first-run setup: everything between "the container is up" and
  # "I can sign in and sell a ticket".
  #
  # Each step is also a standalone rake task and each is idempotent — the wizard
  # detects what already exists and says so instead of failing. Prompts fall
  # back to environment variables (ADMIN_EMAIL, ADMIN_PASSWORD) so a scripted
  # install can run the same code path.
  #
  # Needs a booted app; +root:+ is injected only so the .env writes are testable.
  class Wizard
    HEADER_WIDTH = 68

    DEMO_CODE = 'DEMO'
    DEMO_PERFORMANCE_COUNT = 4
    DEMO_CURTAIN_HOUR = 20
    DEMO_SEATS_PER_CLASS = 25

    def initialize(root: Rails.root, out: $stdout, input: $stdin)
      @out = out
      @input = input
      @scaffold = Scaffold.new(root: root, out: out)
      @env = EnvFile.new(File.join(root.to_s, '.env'))
    end

    def run
      banner 'Stagemgr first-run setup'

      secret_key_base
      bootstrap
      admin
      theater
      site
      payments
      demo_data if yes_no?('Create sample demo data (a production with performances)?', default: true)

      section 'Health check'
      Doctor.new(out: @out).run

      say
      say 'Setup complete. Sign in with the administrator email and password you just chose.'
    end

    def secret_key_base
      section 'Session signing key'
      @scaffold.secret_key_base
      # dotenv already ran, so mirror the new value into this process too —
      # otherwise the doctor run at the end of the wizard reports it missing.
      publish('SECRET_KEY_BASE', @env['SECRET_KEY_BASE'])
    end

    def bootstrap
      section 'Database'
      prepare_database
      if User.exists?
        say "  ✓ database already populated (#{User.count} users)"
      else
        Rake::Task['db:seed'].invoke
        say '  ✓ db:seed done (default users, payment types and lookup data)'
      end
    rescue ActiveRecord::ActiveRecordError => e
      # Rails/Exit is about request-serving code; this only ever runs from a
      # rake task, where stopping with a one-line message beats a backtrace.
      abort "  ✗ database not usable: #{e.message}" # rubocop:disable Rails/Exit
    end

    def admin
      section 'Administrator account'
      email = ENV['ADMIN_EMAIL'].presence || prompt('Administrator email')
      password = ENV['ADMIN_PASSWORD'].presence || prompt_password('Administrator password (>= 8 characters)')

      user = User.find_or_initialize_by(email: email)
      created = user.new_record?
      user.is_administrator = true
      user.is_box_office_user = false
      user.password = password
      user.save!

      say "  ✓ administrator #{email} #{created ? 'created' : 'updated'}"
      @admin_user = user
    end

    def theater
      section 'Theater and venue'
      theater_name = prompt('Theater name', default: Theater.first&.name || 'My Theater')
      venue_name = prompt('Primary venue name', default: Venue.first&.name || 'Main Stage')

      theater = Theater.find_or_initialize_by(name: theater_name)
      theater.theater_class ||= Theater::THEATER_CLASSES.first
      theater.status ||= Theater::THEATER_STATUSES.first
      theater.save!

      venue = Venue.find_or_initialize_by(name: venue_name)
      venue.ordinal_sort ||= 1
      venue.save!

      admin_user = @admin_user || User.where(is_administrator: true).first
      if admin_user && admin_user.theaters.exclude?(theater)
        admin_user.theaters << theater
        say "  ✓ associated #{admin_user.email} with #{theater.name}"
      end

      say "  ✓ theater '#{theater.name}' and venue '#{venue.name}' ready"
      @theater = theater
      @venue = venue
    end

    # Copies sites/example into a theme directory of your own. House copy
    # (addresses, editorial paragraphs, mailer partials) lives there instead of
    # in app/views, so it survives merges from upstream.
    def site
      section 'Site theme'
      slug = prompt('Theme slug for your house copy (blank to skip)', allow_blank: true)
      return say '  ↷ skipped — the generic views will be used' if slug.empty?

      @scaffold.site(slug)
    rescue Scaffold::Error => e
      say "  ✗ #{e.message}"
    end

    def payments
      section 'Payment processing (Stripe)'
      return say '  ↷ skipped — set STRIPE_* later to enable checkout' unless
        yes_no?('Configure Stripe keys now?', default: true)

      secret = prompt_password('STRIPE_SECRET_KEY (sk_test_...)')
      signing = prompt_password('STRIPE_SIGNING_SECRET (whsec_..., blank to skip)', allow_blank: true)

      @env['STRIPE_SECRET_KEY'] = secret
      publish('STRIPE_SECRET_KEY', secret)
      unless signing.empty?
        @env['STRIPE_SIGNING_SECRET'] = signing
        publish('STRIPE_SIGNING_SECRET', signing)
      end

      say "  ✓ Stripe keys written to #{@env.path} (restart the app to pick them up)"
    end

    def demo_data
      section 'Demo data'
      theater = @theater || Theater.first
      venue = @venue || Venue.first
      return say '  ✗ no theater or venue found; run `rake setup:theater` first' if theater.nil? || venue.nil?
      return say "  ↷ demo production '#{DEMO_CODE}' already exists; skipping" if
        Production.exists?(production_code: DEMO_CODE)

      production = create_demo_production(theater, venue)
      classes = create_demo_ticket_classes(production)
      create_demo_performances(production, classes)
    rescue ActiveRecord::RecordInvalid => e
      say "  ✗ could not create demo data: #{e.record.errors.full_messages.to_sentence}"
    end

    private

    # Deliberately neither `db:prepare` nor `db:create`:
    #
    # * Rails 6.1's prepare_all only reaches for db/schema.rb when it hits
    #   NoDatabaseError, but the Docker stack hands us a database MySQL already
    #   created (MYSQL_DATABASE, which is also what grants the app user its
    #   privileges). prepare_all therefore sees an existing-but-empty database
    #   and replays every migration back to 2009 — slow, fragile on MySQL 8, and
    #   it rewrites the committed db/schema.rb on the way out.
    # * `db:create` and `db:schema:load` in the development environment also
    #   reach for the *test* database (DatabaseTasks.each_current_configuration
    #   appends it), which the unprivileged app user is not allowed to touch.
    #
    # So: create only this environment's database, load the schema when the
    # database is empty, and migrate only when something is actually pending.
    def prepare_database
      create_database_if_absent
      unless schema_loaded?
        ActiveRecord::Tasks::DatabaseTasks.load_schema(database_config, ActiveRecord::Base.schema_format)
        say '  ✓ schema loaded from db/schema.rb'
      end

      if ActiveRecord::Base.connection.migration_context.needs_migration?
        migrate_without_dumping_schema
        say '  ✓ pending migrations applied'
      else
        say '  ✓ schema up to date'
      end
    end

    # db/schema.rb is committed, and in development db:migrate rewrites it. That
    # is fine when a developer runs it deliberately; it is not fine from a
    # container boot, where the MySQL version and mysql2 build differ from
    # whoever generated the file and the "change" is pure noise in the diff.
    def migrate_without_dumping_schema
      previous = ActiveRecord::Base.dump_schema_after_migration
      ActiveRecord::Base.dump_schema_after_migration = false
      Rake::Task['db:migrate'].invoke
    ensure
      ActiveRecord::Base.dump_schema_after_migration = previous
    end

    def create_database_if_absent
      ActiveRecord::Base.connection.select_value('SELECT 1')
    rescue ActiveRecord::NoDatabaseError
      ActiveRecord::Tasks::DatabaseTasks.create(database_config)
      # Prove it: DatabaseTasks.create prints and swallows some failures, and
      # "✓ created" followed by a wall of confusing errors is worse than the
      # real exception here.
      ActiveRecord::Base.establish_connection(database_config)
      ActiveRecord::Base.connection.select_value('SELECT 1')
      say "  ✓ created database '#{database_config.database}'"
    end

    def database_config
      @database_config ||= ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).first
    end

    def schema_loaded?
      ActiveRecord::Base.connection.table_exists?(ActiveRecord::Base.schema_migrations_table_name)
    end

    # Makes a freshly written .env value visible to the rest of this process.
    def publish(key, value)
      return if value.blank?

      ENV[key] = value
      AppSecrets.reset! if defined?(AppSecrets)
    end

    def create_demo_production(theater, venue)
      opening = 1.week.from_now
      production = Production.create!(
        name: 'Sample Production', season: Date.current.year.to_s, production_code: DEMO_CODE,
        capacity: DEMO_SEATS_PER_CLASS * 2, status: Production::PRODUCTION_STATUSES.first,
        theater: theater, venue: venue, opening_at: opening, closing_at: 3.weeks.from_now,
        press_opening_at: opening, first_preview_at: opening
      )
      say "  ✓ production '#{production.name}' created"
      production
    end

    def create_demo_ticket_classes(production)
      classes = [['GA', 'General Admission', 25.00], ['STU', 'Student', 15.00]].map do |code, name, price|
        TicketClass.create!(production: production, class_code: code, class_name: name,
                            ticket_type: TicketClass::TICKET_TYPES.first,
                            ticket_price: price, ticketing_fee: 0)
      end
      say '  ✓ ticket classes: GA $25, STU $15'
      classes
    end

    def create_demo_performances(production, ticket_classes)
      DEMO_PERFORMANCE_COUNT.times do |index|
        day = Date.current + (7 + (index * 7)).days
        performance = Performance.create!(
          production: production, performance_code: "#{DEMO_CODE}-#{index + 1}",
          performance_date: day,
          performance_time: Time.zone.local(day.year, day.month, day.day, DEMO_CURTAIN_HOUR, 0),
          status: Performance::PERFORMANCE_STATUSES.first
        )
        ticket_classes.each do |ticket_class|
          TicketClassAllocation.create!(performance: performance, ticket_class: ticket_class,
                                        ticket_limit: DEMO_SEATS_PER_CLASS)
        end
      end
      say "  ✓ #{DEMO_PERFORMANCE_COUNT} performances and allocations created"
    end

    # ── console helpers ────────────────────────────────────────────────────

    def banner(text)
      say
      say '═' * HEADER_WIDTH
      say "  #{text}"
      say '═' * HEADER_WIDTH
    end

    def section(name)
      say
      say "── #{name} #{'─' * [HEADER_WIDTH - name.length - 4, 0].max}"
    end

    def say(message = '')
      @out.puts(message)
    end

    def prompt(question, default: nil, allow_blank: false)
      loop do
        @out.print(default ? "#{question} [#{default}]: " : "#{question}: ")
        value = @input.gets.to_s.chomp
        value = default if value.empty? && default
        return value if !value.empty? || allow_blank

        say '  (a value is required)'
      end
    end

    def prompt_password(question, allow_blank: false)
      loop do
        @out.print "#{question}: "
        value = @input.tty? ? @input.noecho(&:gets).to_s.chomp : @input.gets.to_s.chomp
        say
        return value if !value.empty? || allow_blank

        say '  (a value is required)'
      end
    end

    def yes_no?(question, default: false)
      @out.print "#{question} [#{default ? 'Y/n' : 'y/N'}]: "
      answer = @input.gets.to_s.chomp.downcase
      return default if answer.empty?

      %w[y yes].include?(answer)
    end
  end
end
