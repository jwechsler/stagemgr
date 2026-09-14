# frozen_string_literal: true

# Writes the public, subscribable .ics of everything currently on sale into the
# static cache directory, where the web server hands it out as a plain file.
#
# Times go out as UTC instants (the trailing `Z`), not as local times carrying a
# TZID. That is deliberate: ri_cal answers a TZID by exporting a whole VTIMEZONE
# component, and its exporter still calls TZInfo 1.x's `TimezonePeriod#utc_start`,
# which TZInfo 2 removed -- so any calendar with a zoned event raised. A UTC
# instant needs no VTIMEZONE, is unambiguous, and every calendar client renders
# it in the subscriber's own zone. X-WR-TIMEZONE still names the house's zone so
# clients that show a calendar-wide zone show ours.
class GenerateCalendar
  DEFAULT_FILENAME = 'performances.ics'

  def self.perform(path)
    path = File.join(Rails.configuration.x.server_config['static_cache_dir'], path.presence || DEFAULT_FILENAME)

    cal = RiCal.Calendar do |cal|
      # The subscriber sees the calendar's name in their own calendar app, so it
      # names the house; the timezone is the application's, not a fixed city.
      cal.add_x_property 'X-WR-CALNAME', "#{TheaterInfo.new.name} Performance Calendar"
      cal.add_x_property 'X-WR-TIMEZONE', "VALUE=TEXT:#{Time.zone.tzinfo.identifier}"

      upcoming_performances.each { |perf| add_event(cal, perf) }
    end

    File.write(path, cal.to_s)
    nil
  end

  # Everything visible on an active production from the start of this month on.
  # The current month is included so that a subscriber still sees the run they
  # are in the middle of, not just what is left of it.
  def self.upcoming_performances
    Performance.joins(:production).references(:production).where(
      'productions.status = ? and performances.status in (?) and performance_date > ?',
      Production::ACTIVE, Performance.visible_statuses, Date.current.beginning_of_month
    ).includes(production: :venue)
  end
  private_class_method :upcoming_performances

  def self.add_event(cal, perf)
    starts_at = perf.to_time_with_zone
    order_url = order_url_for(perf)

    cal.event do |event|
      event.dtstart = starts_at.utc
      event.dtend = (starts_at + perf.production.running_time.minutes).utc if perf.production.running_time
      event.summary = perf.production.name
      event.location = perf.production.venue.name
      description = description_for(perf, order_url)
      event.description = description if description.present?
      event.url = order_url if order_url
    end
  end
  private_class_method :add_event

  # The show's own blurb, plus a pointer to the order page while the performance
  # is still sellable. Either half may be missing: a production need not have a
  # description, and a performance already past has nothing to link to.
  def self.description_for(perf, order_url)
    parts = [perf.production.show_description.presence]
    parts << "For tickets, visit #{order_url}" if order_url
    parts.compact.join("\n\n")
  end
  private_class_method :description_for

  # nil once the performance is in the past -- the order page would only offer a
  # sale that can no longer happen.
  def self.order_url_for(perf)
    return nil if perf.performance_date < Date.current

    "#{Rails.configuration.x.server_config['secure_root_url']}" \
      "#{Rails.application.routes.url_helpers.new_production_performance_order_path(
        production_id: perf.production_id, performance_id: perf.id
      )}"
  end
  private_class_method :order_url_for
end
