class BulkOrderImportIssues < Report

  def initialize(reporting_user_id = nil)
    super([:Id,:Name,:PerformanceCode,:Seating,:TicketClass,:Message], reporting_user_id)
    @data['issue'] = Array.new
  end

  def append_issue(id:, customer_name:, performance_code:, seating:, ticket_class:, message:)
    @data['issue'] << {:Id=>id,
              Name:customer_name,
              PerformanceCode: performance_code,
              Seating:seating,
              TicketClass:ticket_class,
              Message: message}
  end

  def any_issues?
    @data.size > 0
  end

  def count
    @data.size
  end

  def create
    file_name = "/tmp/bulk_order_import_issues#{self.reporting_user_id}.csv"
    self.save_report_to_filestore(file_name)
  end

end
