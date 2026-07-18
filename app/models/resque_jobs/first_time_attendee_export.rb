class FirstTimeAttendeeExport < ReportExport
  @queue = :report

  def self.perform(start_date, reporting_user_id, theater_ids = [])
    report = FirstTimeAttendeeReport.new(start_date.to_date, reporting_user_id,
                                         theater_ids: theater_ids)
    send_report(report)
  end
end
