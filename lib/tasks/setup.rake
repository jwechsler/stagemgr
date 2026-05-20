# Interactive first-run setup for Stagemgr.
#
# After cloning, copying .env.example to .env, and bringing the stack up
# (Docker or native), run:
#
#     bundle exec rake setup:wizard
#
# The wizard is idempotent: it detects existing records and skips steps
# that are already done. Sub-tasks can also be invoked individually.

require 'io/console'

namespace :setup do
  desc 'Interactive end-to-end first-run setup'
  task :wizard => :environment do
    SetupWizard.new.run
  end

  desc 'Non-interactive: db:prepare and db:seed (only if database is empty)'
  task :bootstrap => :environment do
    SetupWizard.new.bootstrap
  end

  desc 'Create or update the first administrator user (ADMIN_EMAIL/ADMIN_PASSWORD optional)'
  task :create_admin => :environment do
    SetupWizard.new.create_admin
  end

  desc 'Create the first theater + venue and associate the admin'
  task :create_theater => :environment do
    SetupWizard.new.create_theater
  end

  desc 'Prompt for Stripe test keys and write them to .env'
  task :configure_payments => :environment do
    SetupWizard.new.configure_payments
  end

  desc 'Create one sample production with performances and ticket classes'
  task :demo_data => :environment do
    SetupWizard.new.demo_data
  end
end

class SetupWizard
  HEADER_WIDTH = 64

  def run
    banner 'Stagemgr first-run setup'

    bootstrap
    create_admin
    create_theater
    configure_payments
    if yes_no?('Create sample demo data (a Production with performances)?', default: true)
      demo_data
    end

    say
    say '────────────────────────────────────────────────────────────────'
    say 'Setup complete. Visit your stagemgr install and sign in with the'
    say 'admin email + password you just chose.'
    say '────────────────────────────────────────────────────────────────'
  end

  def bootstrap
    section 'Database'
    Rake::Task['db:prepare'].invoke
    say '  ✓ db:prepare done'
    if User.count.zero?
      Rake::Task['db:seed'].invoke
      say '  ✓ db:seed done (default admin + theater + payment types)'
    else
      say "  ✓ database already populated (#{User.count} users)"
    end
  rescue ActiveRecord::StatementInvalid => e
    abort "  ✗ database not reachable: #{e.message}"
  end

  def create_admin
    section 'Administrator account'
    email    = ENV['ADMIN_EMAIL']    || prompt('Admin email')
    password = ENV['ADMIN_PASSWORD'] || prompt_password('Admin password (>= 8 chars)')

    user = User.find_or_initialize_by(email: email)
    user.is_administrator   = true
    user.is_box_office_user = false
    user.password           = password
    user.save!
    say "  ✓ admin #{email} #{user.previously_new_record? ? 'created' : 'updated'}"
    @admin_user = user
  end

  def create_theater
    section 'Theater and venue'
    name        = prompt('Theater name', default: Theater.first&.name || 'My Theater')
    venue_name  = prompt('Primary venue name', default: Venue.first&.name || 'Main Stage')

    theater = Theater.find_or_initialize_by(name: name)
    theater.theater_class ||= Theater::THEATER_CLASSES.first
    theater.status        ||= Theater::THEATER_STATUSES.first
    theater.save!

    venue = Venue.find_or_initialize_by(name: venue_name)
    venue.ordinal_sort ||= 1
    venue.save!

    admin = @admin_user || User.where(is_administrator: true).first
    if admin && !admin.theaters.include?(theater)
      admin.theaters << theater
      say "  ✓ associated admin #{admin.email} with #{theater.name}"
    end

    say "  ✓ theater '#{theater.name}', venue '#{venue.name}' ready"
    @theater = theater
    @venue   = venue
  end

  def configure_payments
    section 'Payment processing (Stripe)'
    unless yes_no?('Configure Stripe test keys now?', default: true)
      say '  ↷ skipped — set STRIPE_* in .env later to enable checkout'
      return
    end

    pub_key  = prompt('STRIPE_PUBLISHABLE_KEY (pk_test_...)')
    sec_key  = prompt_password('STRIPE_SECRET_KEY (sk_test_...)')
    sig_sec  = prompt_password('STRIPE_SIGNING_SECRET (whsec_..., optional, blank to skip)', allow_blank: true)

    update_env_var('STRIPE_PUBLISHABLE_KEY', pub_key)
    update_env_var('STRIPE_SECRET_KEY',      sec_key)
    update_env_var('STRIPE_SIGNING_SECRET',  sig_sec) unless sig_sec.empty?

    say '  ✓ Stripe keys written to .env (restart the app for them to take effect)'
  end

  def demo_data
    section 'Demo data'
    theater = @theater || Theater.first
    venue   = @venue   || Venue.first
    if theater.nil? || venue.nil?
      say '  ✗ no theater or venue found; run setup:create_theater first'
      return
    end

    code = 'DEMO'
    if Production.exists?(production_code: code)
      say "  ↷ demo production '#{code}' already exists; skipping"
      return
    end

    production = Production.create!(
      name:             'Sample Production',
      season:           Date.current.year.to_s,
      production_code:  code,
      capacity:         50,
      status:           Production::PRODUCTION_STATUSES.first,
      theater:          theater,
      venue:            venue,
      opening_at:       1.week.from_now,
      closing_at:       3.weeks.from_now,
      press_opening_at: 1.week.from_now,
      first_preview_at: 1.week.from_now
    )
    say "  ✓ production #{production.name} created"

    ga = TicketClass.create!(
      production:    production,
      class_code:    'GA',
      class_name:    'General Admission',
      ticket_type:   TicketClass::TICKET_TYPES.first,
      ticket_price:  25.00,
      ticketing_fee: 0
    )
    student = TicketClass.create!(
      production:    production,
      class_code:    'STU',
      class_name:    'Student',
      ticket_type:   TicketClass::TICKET_TYPES.first,
      ticket_price:  15.00,
      ticketing_fee: 0
    )
    say "  ✓ ticket classes: GA $25, STU $15"

    # Four performances on consecutive weekends at 8pm
    4.times do |i|
      day  = Date.current + (7 + i * 7).days
      time = Time.zone.local(day.year, day.month, day.day, 20, 0)
      perf = Performance.create!(
        production:       production,
        performance_code: "#{code}-#{i + 1}",
        performance_date: day,
        performance_time: time,
        status:           Performance::PERFORMANCE_STATUSES.first
      )
      [ga, student].each do |tc|
        TicketClassAllocation.create!(
          performance:  perf,
          ticket_class: tc,
          ticket_limit: 25
        )
      end
    end
    say "  ✓ 4 performances + allocations created"
  end

  # ── helpers ──────────────────────────────────────────────────────────

  def section(name)
    say
    say "── #{name} #{'─' * (HEADER_WIDTH - name.length - 4)}"
  end

  def banner(text)
    say
    say '═' * HEADER_WIDTH
    say "  #{text}"
    say '═' * HEADER_WIDTH
  end

  def say(msg = '')
    puts msg
  end

  def prompt(question, default: nil, allow_blank: false)
    loop do
      print(default ? "#{question} [#{default}]: " : "#{question}: ")
      value = $stdin.gets&.chomp.to_s
      value = default if value.empty? && default
      return value if !value.empty? || allow_blank
      say '  (value required)'
    end
  end

  def prompt_password(question, allow_blank: false)
    loop do
      print "#{question}: "
      value = $stdin.tty? ? $stdin.noecho(&:gets).to_s.chomp : $stdin.gets.to_s.chomp
      puts
      return value if !value.empty? || allow_blank
      say '  (value required)'
    end
  end

  def yes_no?(question, default: false)
    suffix = default ? 'Y/n' : 'y/N'
    print "#{question} [#{suffix}]: "
    answer = $stdin.gets.to_s.chomp.downcase
    return default if answer.empty?
    %w[y yes].include?(answer)
  end

  ENV_PATH = Rails.root.join('.env').freeze

  def update_env_var(key, value)
    lines = File.exist?(ENV_PATH) ? File.read(ENV_PATH).lines : []
    replaced = false
    new_lines = lines.map do |line|
      if line =~ /\A#{Regexp.escape(key)}=/
        replaced = true
        "#{key}=#{value}\n"
      else
        line
      end
    end
    new_lines << "#{key}=#{value}\n" unless replaced
    File.write(ENV_PATH, new_lines.join)
  end
end
