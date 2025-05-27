class FlexPassUsageExport < ReportExport
  @queue = :report
  
  def self.perform(starting_date, ending_date, flex_pass_offer_id, reporting_user_id)
    report = FlexPassUsageReport.new(starting_date, ending_date, flex_pass_offer_id, reporting_user_id)
    self.send_report(report)
  end

end
