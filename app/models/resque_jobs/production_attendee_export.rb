class ProductionAttendeeExport < ReportExport
  @queue = :report

  def self.perform(production_id, export_emails_allowed, reporting_user_id)
    report = ProductionAttendeeReport.new(production_id, export_emails_allowed, reporting_user_id)
    self.send_report(report)
  end
end
