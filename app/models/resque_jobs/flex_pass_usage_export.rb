class FlexPassUsageExport < ReportExport
  @queue = :report

  def self.perform(starting_date, ending_date, flex_pass_offer_ids, reporting_user_id)
    report = FlexPassUsageReport.new(starting_date, ending_date, flex_pass_offer_ids, reporting_user_id)
    send_report(report)
  end
end
