class DonorListExport < ReportExport
  @queue = :report
  def self.perform(starting_date, ending_date, theater_id, reporting_user_id)
    report = DonationList.new(starting_date, ending_date, theater_id, reporting_user_id)
    self.send_report(report)
  end

end
