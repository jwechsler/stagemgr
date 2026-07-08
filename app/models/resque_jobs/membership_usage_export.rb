class MembershipUsageExport < ReportExport
  @queue = :report

  def self.perform(starting_date, ending_date, membership_offer_ids, reporting_user_id)
    report = MembershipUsageReport.new(starting_date, ending_date, reporting_user_id, membership_offer_ids)
    send_report(report)
  end
end
