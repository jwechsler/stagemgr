class GenerateCalendar

  def self.perform(path)
    # cal.timezone do
    #   timezone_id             "America/Chicago"
#
    #   daylight do
    #     timezone_offset_from  "-0600"
    #     timezone_offset_to    "-0500"
    #     timezone_name         "CDT"
    #     dtstart               "19700308TO20000"
    #     add_recurrence_rule   "FREQ=YEARLY;BYMONTH=3;BYDAY=2SU"
    #   end
#
    #   standard do
    #     timezone_offset_from  "-0500"
    #     timezone_offset_to    "-0600"
    #     timezone_name         "CST"
    #     dtstart               "19701101T020000"
    #     add_recurrence_rule   "YEARLY;BYMONTH=11;BYDAY=1SU"
    #   end
    # end

    path = "performances.ics" if path.nil?
    path = $SERVER_CONFIG['static_cache_dir'] + '/' + path

    cal = RiCal.Calendar do |cal|

      cal.add_x_property 'X-WR-CALNAME', 'Theater Wit Performance Calendar'
      cal.add_x_property 'X-WR-TIMEZONE', 'VALUE=TEXT:America/Chicago'

      #cal.default_tzid = 'America/Chicago'
      Performance.where('productions.status = ? and performances.status in (?) and performance_date > ?',Production::ACTIVE,Performance.visible_statuses,Date.today.beginning_of_month).includes(:production).each do |perf|

        # = { "X-WR-CALNAME"=>"", "X_WR_TIMEZONE"=>"VALUE=TEXT:America/Chicago", "X-ALT_DESC"=>"FMTTYPE=text/html:<!DOCTYPE HTMLS PUBLIC \"-//W3C//DTD HTMLS 3.2//EN\"\n<HTML><BODY>#{$MARKDOWN.render(perf.production.show_description)}</BODY></HTML>"}
        desc = perf.production.show_description
        desc = desc + "\n\nFor tickets, visit #{$SERVER_CONFIG['secure_root_url']}#{Rails.application.routes.url_helpers.new_production_performance_order_path(:production_id=>perf.production_id, :performance_id => perf.id)}" unless perf.performance_date < Date.today
        cal.event do |event|
          event.dtstart = perf.to_time_with_zone
          event.dtend = perf.to_time_with_zone + perf.production.running_time.minutes unless perf.production.running_time.nil?
          event.summary = perf.production.name
          event.location = perf.production.venue.name
          event.url = "#{$SERVER_CONFIG['secure_root_url']}#{Rails.application.routes.url_helpers.new_production_performance_order_path(:production_id=>perf.production_id, :performance_id => perf.id)}" unless perf.performance_date < Date.today
          # event.dtstart.timezone_id = {"TZID"=>"America/Chicago"}
        end
      end
    end
    output_file = File.new(path,'w')
    output_file.write(cal.to_s)
    output_file.close
    nil
  end

end
