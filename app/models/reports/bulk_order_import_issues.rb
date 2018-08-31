class BulkOrderImportIssues < Report

  def initialize(reporting_user_id = nil)
    super(reporting_user_id)
    @headers += [:Id,:Name,:PerformanceCode,:Seating,:TicketClass]
  end

  def create(issues_list)
    CSV
    self.data << issue.join(',')
    file_name = "/tmp/import_issues_#{reporting_user_id}.csv"
    self.save_report_to_filestore(file_name, issues_list.)

  end
end
