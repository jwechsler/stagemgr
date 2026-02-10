class ImportIssuesReport < SimpleReport

  # basic report -> simple rows/headers

  attr_reader :reporting_user_id
  attr_accessor :headers
  attr_accessor :data

  def initialize(headers, reporting_user_id = nil)
    @headers = headers + ['Error']
    super(headers, reporting_user_id)
  end

  def add_problem_row(row:, message:)
    if row.is_a?(Hash)
      @headers = row.keys + ['Error'] if @headers == ['Error']
      data << row.values + [message]
    else
      data << row + [message]
    end
  end

  def any_issues?
    @data.size > 0
  end

  def count
    @data.size
  end

  def create
    unless @headers.empty?
      notes = "#{@data.size} error#{@data.size > 1 ? 's' : ''}"
      file_name = "/tmp/import_issues_#{self.reporting_user_id}_#{Time.now.seconds_since_midnight}.csv"
      fs = self.save_report_to_filestore(file_name, notes)
      fs.save
      fs
    else
      nil
    end
  end

  protected
  def self.new_address_tag(theater_id, address, tag_label, tag_value)
    sub_tag = AddressTag.new
    sub_tag.address = address
    sub_tag.tag_label = tag_label
    sub_tag.tag_value = tag_value
    sub_tag.theater_id = theater_id
    sub_tag
  end

end

