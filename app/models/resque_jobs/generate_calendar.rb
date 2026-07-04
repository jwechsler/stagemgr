class GenerateCalendar
  def self.perform(path)
    path = 'performances.ics' if path.nil?
    path = Rails.configuration.x.server_config['static_cache_dir'] + '/' + path

    cal = RiCal.Calendar do |cal|
      cal.add_x_property 'X-WR-CALNAME', 'Theater Wit Performance Calendar'
      cal.add_x_property 'X-WR-TIMEZONE', 'VALUE=TEXT:America/Chicago'

      # cal.default_tzid = 'America/Chicago'
      Performance.joins(:production).references(:production).where(
        'productions.status = ? and performances.status in (?) and performance_date > ?', Production::ACTIVE, Performance.visible_statuses, Date.today.beginning_of_month
      ).includes(:production).each do |perf|
        # = { "X-WR-CALNAME"=>"", "X_WR_TIMEZONE"=>"VALUE=TEXT:America/Chicago", "X-ALT_DESC"=>"FMTTYPE=text/html:<!DOCTYPE HTMLS PUBLIC \"-//W3C//DTD HTMLS 3.2//EN\"\n<HTML><BODY>#{Rails.configuration.x.markdown.render(perf.production.show_description)}</BODY></HTML>"}
        desc = perf.production.show_description
        unless perf.performance_date < Date.today
          desc + "\n\nFor tickets, visit #{Rails.configuration.x.server_config['secure_root_url']}#{Rails.application.routes.url_helpers.new_production_performance_order_path(
            production_id: perf.production_id, performance_id: perf.id
          )}"
        end
        cal.event do |event|
          event.dtstart = perf.to_time_with_zone
          unless perf.production.running_time.nil?
            event.dtend = perf.to_time_with_zone + perf.production.running_time.minutes
          end
          event.summary = perf.production.name
          event.location = perf.production.venue.name
          unless perf.performance_date < Date.today
            event.url = "#{Rails.configuration.x.server_config['secure_root_url']}#{Rails.application.routes.url_helpers.new_production_performance_order_path(
              production_id: perf.production_id, performance_id: perf.id
            )}"
          end
        end
      end
    end
    output_file = File.new(path, 'w')
    output_file.write(cal.to_s)
    output_file.close
    nil
  end
end
