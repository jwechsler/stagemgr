class FlexPassPatronReportJob < ReportExport
  @queue = :report

  def self.perform(starting_date, ending_date, reporting_user_id)
    report = FlexPassPatronReport.new(starting_date, ending_date, reporting_user_id)
    self.send_report(report)
  end
end
