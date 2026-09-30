# frozen_string_literal: true

# Guards against app code that prints a Time with a bare #to_s.
#
# On Rails 6.1, Time#to_s, DateTime#to_s and TimeWithZone#to_s with no
# argument use Time::DATE_FORMATS[:default] ('%m/%d/%Y', config/environment.rb).
# Rails 7.1 stops consulting :default for to_s, so every such call -- including
# the implicit ones: "#{time}", Array#join, CSV rows, puts, ERB `<%= time %>`,
# HAML `= time`, a Time passed as a form value or to I18n -- would silently
# start printing "2026-09-28 19:30:00 -0500". Use
# time.to_formatted_s(:default) (or a named format) instead.
#
# Loaded by spec/rails_helper.rb and features/support/bare_time_to_s.rb. It
# records each call site in app/, lib/, sites/ or config/ that reaches a bare
# to_s, and fails the run at the end if there are any. Set
# BARE_TIME_TO_S=report to list them without failing.
#
# A call is attributed to the first frame outside Ruby's core and a short list
# of pass-through libraries (the view/rendering stack, CSV, I18n). A call made
# from inside any other gem (Active Record, Mail, loggers ...) is that gem's
# business and is ignored, as are calls from spec/ and features/.
# HAML templates may report a line one below the `= value` that printed it.
#
# Remove this file (and its two requires) once the app is on Rails 7.1+, where
# to_s no longer reads DATE_FORMATS[:default] and the question is moot.
module BareTimeToSDetector
  ROOT = "#{Rails.root}/".freeze # rubocop:disable Rails/FilePath -- a prefix string, not a path to open
  APP_DIRS = %w[app/ lib/ sites/ config/].map { |dir| ROOT + dir }.freeze
  TEST_DIRS = %w[spec/ features/].map { |dir| ROOT + dir }.freeze
  PASS_THROUGH = %r{
    /gems/(?:actionview|actionpack|activesupport|haml|simple_form|draper|i18n|csv|erubi)-[^/]+/ |
    /lib/ruby/\d+\.\d+\.\d+/(?:csv|erb) |
    \A<internal:
  }x
  MUTEX = Mutex.new
  SITES = {} # rubocop:disable Style/MutableConstant -- "path:line" => call count, filled at run time

  module_function

  def record(locations)
    site = attribute(locations)
    return unless site

    MUTEX.synchronize { SITES[site] = SITES.fetch(site, 0) + 1 }
  end

  def attribute(locations)
    locations.each do |location|
      path = location.absolute_path || location.path.to_s
      return "#{path.delete_prefix(ROOT)}:#{location.lineno}" if APP_DIRS.any? { |dir| path.start_with?(dir) }
      return nil if TEST_DIRS.any? { |dir| path.start_with?(dir) }
      return nil unless path.match?(PASS_THROUGH)
    end
    nil
  end

  def report_only?
    ENV['BARE_TIME_TO_S'] == 'report'
  end

  def report
    return nil if SITES.empty?

    lines = SITES.sort.map do |site, count|
      path, line = site.split(/:(?=\d+\z)/)
      source = File.readlines(ROOT + path)[line.to_i - 1].to_s.strip rescue '' # rubocop:disable Style/RescueModifier
      "  #{site} (#{count}x)  #{source[0, 120]}"
    end
    <<~MSG
      Bare Time#to_s reached from app code at #{SITES.size} site(s). On Rails 7.1+ these
      print "YYYY-MM-DD HH:MM:SS -ZZZZ" instead of Time::DATE_FORMATS[:default].
      Call to_formatted_s(:default) (or a named format) explicitly:
      #{lines.join("\n")}
    MSG
  end

  # Prepended to Time, DateTime and ActiveSupport::TimeWithZone.
  module Hook
    def to_s(*args)
      BareTimeToSDetector.record(caller_locations(1, 40)) if args.empty? || args == [:default]
      super
    end
  end

  [Time, DateTime, ActiveSupport::TimeWithZone].each { |klass| klass.prepend(Hook) }
end
