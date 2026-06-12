class SimpleReport < Report
  def initialize(headers, reporting_user_id = nil)
    super(headers, reporting_user_id)
    @data = Array.new
  end

  def save_report_as_csv(file_path, filestore)
    csv_string = CSV.generate do |csv|
      csv << self.headers
      self.data.each { |row| csv << row }
    end
    self.write_file_data(file_path, filestore, csv_string)
  end
end
