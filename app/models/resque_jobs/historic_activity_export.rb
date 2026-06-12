class HistoricActivityExport
  @queue = :report
  include Admin::ReportsHelper

  def self.perform(start_day, minimum_attended = 0, required_theater_ids = [], minimum_revenue = 0.0,
                   reporting_user_id = nil)
    report = HistoricActivityReport.new(start_day, minimum_attended, required_theater_ids, minimum_revenue,
                                        reporting_user_id)
    report.create
  end
end
