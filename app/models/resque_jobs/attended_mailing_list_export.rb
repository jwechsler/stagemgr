class AttendedMailingListExport
  @queue = :report
  include Admin::ReportsHelper

  def self.perform(starting_date, ending_date, reporting_user_id)
    report = AttendedMailingList.new(starting_date, ending_date, reporting_user_id)
    fs = report.create
  end

end
