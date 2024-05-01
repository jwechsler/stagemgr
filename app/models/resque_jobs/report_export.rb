class ReportExport
  @queue = :report
  include Admin::ReportsHelper
  include NotifyOnCompletion

  protected
  def self.send_report(report)
    fs = report.create
    notify_user_on_completion(fs)
  end

end
