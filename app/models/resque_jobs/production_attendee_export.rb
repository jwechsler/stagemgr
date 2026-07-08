class ProductionAttendeeExport < ReportExport
  @queue = :report

  # production_ids may be a single id (legacy scalar jobs) or an array; the
  # report normalizes it via Array().
  def self.perform(production_ids, export_emails_allowed, reporting_user_id)
    report = ProductionAttendeeReport.new(production_ids, export_emails_allowed, reporting_user_id)
    send_report(report)
  end
end
