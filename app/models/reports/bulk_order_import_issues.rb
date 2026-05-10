class BulkOrderImportIssues < ImportIssuesReport

  def initialize(reporting_user_id = nil)
    super([], reporting_user_id)    
  end

  def append_issue(id:, customer_name:, performance_code:, seating:, order_detail:, message:)
    @data << {:Id=>id,
              Name:customer_name,
              PerformanceCode: performance_code,
              Seating:seating,
              OrderDetail:order_detail,
              Error: message}
  end

end
