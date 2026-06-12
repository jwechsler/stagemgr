require 'csv'

class Report
  include NotifyOnCompletion

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

  def save_report_to_filestore(file_name, notes = 'Report')
    # now, output the various production reports
    # @todo refactor for new delf.data format.
    file_store = FileStore.new
    file_store.worker = FileStore::REPORT
    file_store.user_id = self.reporting_user_id
    file_store.notes = notes
    self.save_report_as_csv(file_name, file_store)
  end

  def save_report_as_csv(file_path, filestore = nil)
    csv_string = CSV.generate do |csv|
      csv << self.headers
      if self.data.is_a? Hash
        self.data.each { |key, rows|
          rows.each { |row|
            csv << headers.map { |h|
              h == :Segment ? key : Report.tidy_output(row[h])
            } unless row.nil?
          }
        } else # if simple array, then dump array into csv
            self.data.each { |row|
              csv << headers.map { |h| Report.tidy_output(row[h]) }
            }
      end
    end
    self.write_file_data(file_path, filestore, csv_string)
  end

  def write_file_data(file_path, filestore, data)
    f = File.new(file_path, 'w')
    f.puts(data)
    f.close
    unless filestore.nil?
      filestore.datafile.attach(io: File.open(file_path), filename: File.basename(file_path),
                                content_type: "text/plain")
      filestore.worker = FileStore::REPORT
      filestore.save
      File.delete(file_path)
      # @todo notify user that report is generated
      filestore
    else
      file_path
    end
  end

  protected

  def report_filename(filename)
    dir_name = File.dirname(filename)
    extension = File.extname(filename)
    extension = ".csv" if extension.blank?

    # Only honor an explicitly supplied directory that actually exists. A bare
    # filename built from user data (e.g. a production name containing "/")
    # makes File.dirname report a phantom directory, which previously slipped
    # past the "." / empty check and caused File.new to raise Errno::ENOENT.
    # In that case the leading path fragment is really part of the name, so we
    # sanitize the whole filename and write to the system tmpdir.
    if dir_name != '.' && !dir_name.empty? && Dir.exist?(dir_name)
      base_filename = File.basename(filename, File.extname(filename))
      sanitized_filename = "#{base_filename.parameterize}#{extension}"
    else
      dir_name = Dir.tmpdir
      name_without_extension = filename.delete_suffix(File.extname(filename))
      sanitized_filename = "#{name_without_extension.parameterize}#{extension}"
    end

    full_path = File.join(dir_name, sanitized_filename)

    return full_path.to_s
  end

  def report_data(file_name = nil)
    unless reporting_user_id.nil?
      self.save_report_to_filestore(file_name)
    else
      return [self.headers, self.data]
    end
  end
end
