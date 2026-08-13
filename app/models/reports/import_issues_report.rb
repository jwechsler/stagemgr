class ImportIssuesReport < SimpleReport
  # basic report -> simple rows/headers

  attr_reader :reporting_user_id
  attr_accessor :headers, :data

  def initialize(headers, reporting_user_id = nil)
    super
    # Report#initialize sets @headers = headers, so append the Error column
    # *after* super has run, otherwise it gets overwritten.
    @headers = headers + ['Error']
  end

  def add_problem_row(row:, message:)
    if row.is_a?(Hash)
      @headers = row.keys + ['Error'] if @headers == ['Error']
      data << (row.values + [message])
    else
      data << (row + [message])
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
    @data.map { |row| row.is_a?(Hash) ? row[:Error] : row.last }.compact_blank
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
    return unless @data.any?

    errors = error_messages
    notes = "#{errors.size} error#{'s' unless errors.size == 1} in #{@data.size} row#{'s' unless @data.size == 1}"
    notes += ": #{errors.last.to_s.truncate(120)}" if errors.any?
    suffix = if import_name.present?
               ImportIssuesReport.regularize_name(import_name)
             else
               "#{reporting_user_id}_#{Time.now.seconds_since_midnight}"
             end
    file_name = "/tmp/#{result_prefix}_#{suffix}.csv"
    fs = save_report_to_filestore(file_name, notes)
    fs.save
    fs
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

  def self.new_address_tag(theater_id, address, tag_label, tag_value)
    sub_tag = AddressTag.new
    sub_tag.address = address
    sub_tag.tag_label = tag_label
    sub_tag.tag_value = tag_value
    sub_tag.theater_id = theater_id
    sub_tag
  end

  # Shared by the bulk order/flex imports: resolve the row to an address by
  # Id, then ExternalId tag, else a new record; apply the row's contact
  # fields and tags; and fold a would-be new record into its existing
  # original rather than importing a duplicate patron. Caller saves.
  def self.imported_address(row, theater_id, external_address_ids)
    a = if row['Id'].present? # if ID is present, use that as the match criteria
          Address.find_by(id: row['Id'].to_i)
        elsif row['ExternalId'].present?
          Address.find_by(id: external_address_ids[row['ExternalId']])
        end
    a ||= Address.new
    unless row['FullName'].blank? && row['LastName'].blank?
      a.set_full_name(row['FullName'], row['FirstName'], row['MiddleName'], row['LastName'])
    end
    a.line1 = row['Address'] if row['Address'].present?
    a.line2 = row['Address2'] if row['Address2'].present?
    a.email = row['EmailAddress'] if row['EmailAddress'].present?
    a.city = row['City'] if row['City'].present?
    a.zipcode = row['ZipCode'] if row['ZipCode'].present?
    a.phone = row['Phone'] if row['Phone'].present?
    a.address_tags << new_address_tag(theater_id, a, row['Tag1'], row['TagValue1']) if row['Tag1'].present?
    a.address_tags << new_address_tag(theater_id, a, row['Tag2'], row['TagValue2']) if row['Tag2'].present?
    a.address_tags << new_address_tag(theater_id, a, 'External ID', row['ExternalId']) if row['ExternalId'].present?
    a.regularize!
    a.fold_into_original
  end
end
