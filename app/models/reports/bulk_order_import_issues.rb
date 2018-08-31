class BulkOrderImportIssues < Report

  def initialize(reporting_user_id = nil)
    super(reporting_user_id)
    @headers += [:Id,:Name,:PerformanceCode,:Seating,:TicketClass]
  end

  def append_problem(row, message)
  def create()

  end
end
