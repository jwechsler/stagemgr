class BulkOrderImportIssues < Report

  def initialize(reporting_user_id = nil)
    super([], reporting_user_id)
    @data['issue'] = Array.new
  end

  def append_issue(id:, customer_name:, performance_code:, seating:, order_detail:, message:)
    @data['issue'] << {:Id=>id,
              Name:customer_name,
              PerformanceCode: performance_code,
              Seating:seating,
              OrderDetail:order_detail,
              Message: message}
  end

  def any_issues?
    @data.size > 0
  end

  def count
    @data.size
  end

  def create
    unless @headers.empty?
      puts "LOGGING HAPPENING"
      notes = "#{@data.size} error#{@data.size > 1 ? 's' : ''}"
      file_name = "/tmp/bulk_order_import_issues#{self.reporting_user_id}.csv"
      fs = self.save_report_to_filestore(file_name, notes)
      fs
    else
      nil
    end
  end

end
