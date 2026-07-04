class AudienceCohortExport < ReportExport
  @queue = :report

  def self.perform(target_production_id, comparison_theater_ids, segment_key,
                   window_label, allow_email_export, theater_ids,
                   reporting_user_id)
    report = AudienceCohortReport.new(
      target_production_id, comparison_theater_ids, segment_key,
      window_label, allow_email_export, theater_ids, reporting_user_id
    )
    send_report(report)
  end
end
