class Report

  attr_accessor :headers
  attr_accessor :data
  attr_reader :reporting_user_id

  def initialize(headers, reporting_user_id = nil)
    @headers = headers
    @data = Hash.new
    @reporting_user_id = reporting_user_id
  end

  def self.tidy_output(f)
    Admin::ReportsHelper.tidy_output(f)
  end


  def save_report_to_filestore(file_name, notes='Report')
    # now, output the various production reports
    # @todo refactor for new delf.data format.
    file_store = FileStore.new
    file_store.worker = FileStore::REPORT
    file_store.user_id = self.reporting_user_id
    file_store.notes = notes
    file_store.save!
    self.save_report_as_csv(file_name, file_store)
  end

  def save_report_as_csv(file_path, filestore=nil)
    csv_string = CSV.generate do |csv|
      csv << self.headers
      self.data.each { |key, rows| rows.each { |row|
          csv << headers.map { |h| h == :Segment ? key : Report.tidy_output(row[h]) } unless row.nil? }
      }
    end
    self.write_file_data(file_path, filestore, csv_string)
  end

  def write_file_data(file_path, filestore, data)
    f = File.new(file_path,'w')
    f.puts(data)
    f.close
    unless filestore.nil?
      filestore.data = File.open(file_path)
      filestore.worker = FileStore::REPORT
      filestore.save
      File.delete(file_path)
      # @todo notify user that report is generated
      filestore

    else
      file_path
    end
  end


end
