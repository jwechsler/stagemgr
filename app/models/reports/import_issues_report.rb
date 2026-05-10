class ImportIssuesReport < SimpleReport

  # basic report -> simple rows/headers

  attr_reader :reporting_user_id
  attr_accessor :headers
  attr_accessor :data

  def initialize(headers, reporting_user_id = nil)
    super(headers, reporting_user_id)
    # Report#initialize sets @headers = headers, so append the Error column
    # *after* super has run, otherwise it gets overwritten.
    @headers = headers + ['Error']
  end

  def add_problem_row(row:, message:)
    if row.is_a?(Hash)
      @headers = row.keys + ['Error'] if @headers == ['Error']
      data << row.values + [message]
    else
      data << row + [message]
    end
  end

  # Formats an exception into a single-line description suitable for the
  # per-row Error column. Includes the exception class so users can tell
  # validation failures from runtime/state-machine errors at a glance.
  def self.format_exception(e)
    detail = e.message.to_s.gsub(/\s+/, ' ').strip
    detail = '(no message)' if detail.empty?
    "#{e.class.name}: #{detail}".truncate(500)
  end

  # All error messages collected across rows. Used for both the file notes
  # summary and to decide whether any row actually failed.
  def error_messages
    @data.map { |row| row.is_a?(Hash) ? row[:Error] : row.last }.select(&:present?)
  end

  def any_issues?
    error_messages.any?
  end

  def count
    error_messages.size
  end

  # Emit the result CSV. Each importer supplies its own `result_prefix` so the
  # generated filename describes the import type (e.g. order_import_results_*,
  # flex_pass_import_results_*, donor_import_results_*). `import_name` is the
  # original upload filename, which gets sanitised via regularize_name so the
  # resulting filename is safe for shell/filesystem use.
  def create(import_name: nil, result_prefix: 'import_results')
    if @data.any?
      errors = error_messages
      notes = "#{errors.size} error#{errors.size == 1 ? '' : 's'} in #{@data.size} row#{@data.size == 1 ? '' : 's'}"
      notes += ": #{errors.last.to_s.truncate(120)}" if errors.any?
      suffix = import_name.present? ?
        ImportIssuesReport.regularize_name(import_name) :
        "#{self.reporting_user_id}_#{Time.now.seconds_since_midnight}"
      file_name = "/tmp/#{result_prefix}_#{suffix}.csv"
      fs = self.save_report_to_filestore(file_name, notes)
      fs.save
      fs
    else
      nil
    end
  end

  # Strip a filename down to a shell-safe basename: drop the extension, then
  # replace any run of characters outside [A-Za-z0-9-] (which includes spaces,
  # parens, ampersands, *and* underscores themselves) with a single underscore.
  # Trim leading/trailing underscores. Falls back to "import" if nothing
  # printable remains. Examples:
  #   "My File (1).csv"        -> "My_File_1"
  #   "orders & holds.tsv"     -> "orders_holds"
  #   "weird   ___ name.csv"   -> "weird_name"
  def self.regularize_name(name)
    base = File.basename(name.to_s, '.*')
    cleaned = base.gsub(/[^A-Za-z0-9-]+/, '_').gsub(/\A_+|_+\z/, '')
    cleaned.presence || 'import'
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

