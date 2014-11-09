class TrgExport
  @queue = :report
  include Admin::ReportsHelper

  def self.perform(production_id, reporting_user_id)
    p = Production.find(production_id)
    report = ProductionMailingList.new
    fs = report.create(p, reporting_user_id)
  end
end
