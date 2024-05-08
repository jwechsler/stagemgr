class TrgProductionAttendeeExportJob < ApplicationJob
  @queue =  :report
  include Admin::ReportsHelper
  include NotifyOnCompletion

  def self.perform(production_id, reporting_user_id, allow_email_exports)
    p = Production.find(production_id)
    report = TrgProductionAttendeeReport.new(p, reporting_user_id, allow_email_exports)
    fs = report.create
    notify_user_on_completion(fs)
  end
end
