class TrgExport
  @queue = :report
  include Admin::ReportsHelper

  def self.perform(production_id, reporting_user_id, allow_email_exports)
    p = Production.find(production_id)
    report = ProductionMailingList.new(p, reporting_user_id, allow_email_exports)
    fs = report.create
  end
end
