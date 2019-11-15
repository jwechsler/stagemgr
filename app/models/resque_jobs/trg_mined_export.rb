class TrgMinedExport
  @queue = :report
  include Admin::ReportsHelper
  include NotifyOnCompletion

  def self.perform(minimum_attended, minimum_revenue, start_date, required_theater_ids, reporting_user_id = nil)
    report = CustomerMailingList.new(minimum_attended, minimum_revenue, start_date, required_theater_ids, reporting_user_id)
    fs = report.create
    notify_user_on_completion(fs)
  end
end
