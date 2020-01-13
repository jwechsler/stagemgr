class DonorListExport
  @queue = :report
  include Admin::ReportsHelper
  include NotifyOnCompletion

  def self.perform(starting_date, ending_date, reporting_user_id)
    report = DonationList.new(starting_date, ending_date, reporting_user_id)
    fs = report.create
    notify_user_on_completion(fs)
  end

end
