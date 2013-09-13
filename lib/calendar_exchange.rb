class CalendarExchange
  include Icalendar

  def self.publish_calendar(path)
    cal = Calendar.new
    base_url = YAML

    Performance.where('status in (?) and performance_date > ?',Performance.visible_statuses,Date.today.beginning_of_month).includes(:production).each do |perf|
      params = { "X-ALT_DESC"=>"FMTTYPE=text/html:<!DOCTYPE HTMLS PUBLIC \"-//W3C//DTD HTMLS 3.2//EN\"\n<HTML><BODY>#{perf.production.show_description_as_html}</BODY></HTML>"}
      desc = perf.production.show_description_as_text
      desc = desc + "\n\nFor tickets, visit #{$SERVER_CONFIG['secure_root_url']}#{Rails.application.routes.url_helpers.new_production_performance_order_path(:production_id=>perf.production_id, :performance_id => perf.id)}" unless perf.performance_date < Date.today
      event = cal.event do
        dtstart     perf.to_datetime
        dtend       perf.to_datetime + perf.production.running_time.minutes unless perf.production.running_time.nil?
        summary     perf.production.name
        location    perf.production.venue.name
        url         "#{$SERVER_CONFIG['secure_root_url']}#{Rails.application.routes.url_helpers.new_production_performance_order_path(:production_id=>perf.production_id, :performance_id => perf.id)}" unless perf.performance_date < Date.today

      end
    end
    output_file = File.new(path,'w')
    output_file.write(cal.to_ical)
    output_file.close
    cal.to_ical
  end

end
