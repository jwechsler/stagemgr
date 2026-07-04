class SimpleReport < Report
  def initialize(headers, reporting_user_id = nil)
    super
    @data = []
  end

  def save_report_as_csv(file_path, filestore)
    csv_string = CSV.generate do |csv|
      csv << headers
      data.each { |row| csv << row }
    end
    write_file_data(file_path, filestore, csv_string)
  end
end
