class AttendedMailingListExport
  @queue = :report
  include Admin::ReportsHelper
  include NotifyOnCompletion

  def self.perform(starting_date, ending_date, reporting_user_id, theater_ids = [])
    report = AttendedMailingList.new(starting_date, ending_date, reporting_user_id, theater_ids: theater_ids)
    fs = report.create
    notify_user_on_completion(fs)
  end

end
