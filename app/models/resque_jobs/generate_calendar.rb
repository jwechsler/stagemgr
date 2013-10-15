class GenerateCalendar
  include Icalendar

  def self.perform(path)
    cal = Calendar.new
    cal.timezone do
      timezone_id             "America/Chicago"

      daylight do
        timezone_offset_from  "-0600"
        timezone_offset_to    "-0500"
        timezone_name         "CDT"
        dtstart               "19700308TO20000"
        add_recurrence_rule   "FREQ=YEARLY;BYMONTH=3;BYDAY=2SU"
      end

      standard do
        timezone_offset_from  "-0500"
        timezone_offset_to    "-0600"
        timezone_name         "CST"
        dtstart               "19701101T020000"
        add_recurrence_rule   "YEARLY;BYMONTH=11;BYDAY=1SU"
      end
    end

    path = "performances.ics" if path.nil?
    path = $SERVER_CONFIG['static_cache_dir'] + '/' + path

    Performance.where('productions.status = ? and performances.status in (?) and performance_date > ?',Production::ACTIVE,Performance.visible_statuses,Date.today.beginning_of_month).includes(:production).each do |perf|
      #params = { "X-ALT_DESC"=>"FMTTYPE=text/html:<!DOCTYPE HTMLS PUBLIC \"-//W3C//DTD HTMLS 3.2//EN\"\n<HTML><BODY>#{$MARKDOWN.render(perf.production.show_description)}</BODY></HTML>"}
      desc = perf.production.show_description
      desc = desc + "\n\nFor tickets, visit #{$SERVER_CONFIG['secure_root_url']}#{Rails.application.routes.url_helpers.new_production_performance_order_path(:production_id=>perf.production_id, :performance_id => perf.id)}" unless perf.performance_date < Date.today
      event = cal.event
      event.dtstart = perf.to_datetime
      event.dtend = perf.to_datetime + perf.production.running_time.minutes unless perf.production.running_time.nil?
      event.summary = perf.production.name
      event.location = perf.production.venue.name
      event.url = "#{$SERVER_CONFIG['secure_root_url']}#{Rails.application.routes.url_helpers.new_production_performance_order_path(:production_id=>perf.production_id, :performance_id => perf.id)}" unless perf.performance_date < Date.today
      event.dtstart.ical_params = {"TZID"=>"America/Chicago"}
    end
    output_file = File.new(path,'w')
    output_file.write(cal.to_ical)
    output_file.close
    nil
  end

end
