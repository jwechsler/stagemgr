require 'csv'

# LglDonorImport loads donor tiers from a Little Green Light export (the
# scheduled LGL saved report or a manual upload on the Imports page). The file
# needs three columns, matched case-insensitively:
#
#   'External constituent ID'  the Stagemgr address id; the main match key
#   'TG Tier Last Fiscal'      donor tier for the previous fiscal year
#   'TG Tier This Fiscal'      donor tier for the current fiscal year
#
# and may have a fourth, 'LGL Constituent ID'. When a row's External
# constituent ID is blank or a number that matches no customer, that LGL id is
# looked up in the customers' LGL ID tags (Lgl::Reconciler.tagged_addresses):
# one tagged customer is matched as usual and also counted as matched by LGL
# ID; several make an error row (they should be merged); none, or no usable LGL
# id, leaves the row as it would be without the fallback (skipped when the
# External constituent ID is blank, an error when it matches no customer). An
# External constituent ID that is not a number never falls back.
#
# Each matched row sets both tiers (blank cells clear them). The import never
# creates, merges or renames customers. Once the whole file has loaded, every
# customer with a tier who was not in the file has both tiers cleared, so the
# file is the complete list of current donors.
#
# Rows without an External constituent ID that no LGL ID tag resolves
# (organisations, and constituents not yet copied into Stagemgr) are skipped
# and only counted. The result file lists only the rows that have an entry in
# the Error column (an id that is not a number, a number that matches no
# customer and whose LGL id no tag resolves, an LGL id tagged on several
# customers, or a failed save); these are the rows counted as errors. It has
# the upload's own columns plus Error and is created only when some row has an
# error. When the import finishes, the
# uploader (the supervisor-notifications user for the nightly LGL run) is
# always emailed the counts, with the result file attached when there is one.
class LglDonorImport < ImportIssuesReport
  include LoggedJob

  ID_HEADER = 'External constituent ID'.freeze
  LAST_HEADER = 'TG Tier Last Fiscal'.freeze
  CURRENT_HEADER = 'TG Tier This Fiscal'.freeze
  REQUIRED_HEADERS = [ID_HEADER, LAST_HEADER, CURRENT_HEADER].freeze
  LGL_ID_HEADER = 'LGL Constituent ID'.freeze
  CSV_OPTIONS = { encoding: 'bom|utf-8' }.freeze
  CLEAR_BATCH_SIZE = 1000
  TIER_COLUMNS = %i[donor_tier_for_last_fiscal_year donor_tier_for_current_fiscal_year].freeze
  ROW_MESSAGES = {
    bad_id: "#{ID_HEADER} is not a number",
    unmatched: "No customer with this #{ID_HEADER}"
  }.freeze

  @queue = :import

  def self.perform(filestore_id)
    filestore = FileStore.find(filestore_id)
    filestore.notes = 'Importing Donor Levels...'
    filestore.save
    columns = header_columns(filestore)
    problems = ImportIssuesReport.new([], filestore.user_id)
    counts = import_rows(filestore, columns, problems)
    filestore.notes = summary(counts)
    filestore.save
    notify_uploader(filestore, counts, write_results(filestore, problems))
  end

  # Maps each required header, and the optional LGL id header (nil when the
  # file lacks it), to the file's own spelling of it.
  def self.header_columns(filestore)
    header_row = CSV.open(filestore.path, **CSV_OPTIONS, &:shift) || []
    lookup = header_row.compact.index_by { |header| header.strip.downcase }
    columns = REQUIRED_HEADERS.index_with { |name| lookup[name.downcase] }
    missing = columns.select { |_name, header| header.nil? }.keys
    return columns.merge(LGL_ID_HEADER => lookup[LGL_ID_HEADER.downcase]) if missing.empty?

    filestore.notes = "Donor levels import failed: missing column #{missing.join(', ')}"
    filestore.save
    raise ArgumentError, filestore.notes
  end

  def self.import_rows(filestore, columns, problems)
    counts = Hash.new(0)
    seen_ids = Set.new
    CSV.foreach(filestore.path, headers: true, **CSV_OPTIONS) do |row|
      counts[:rows] += 1
      outcome, message, by_lgl_id = import_row(row, columns, seen_ids)
      counts[outcome] += 1
      counts[:by_lgl_id] += 1 if by_lgl_id
      problems.add_problem_row(row: row.to_h, message: message) if message
    end
    counts[:cleared_absent] = clear_absent(seen_ids)
    counts
  end

  def self.import_row(row, columns, seen_ids)
    raw_id = row[columns[ID_HEADER]].to_s.strip
    return import_by_lgl_id(row, columns, seen_ids, [:blank_id, nil]) if raw_id.empty?
    return outcome_with_message(:bad_id) unless raw_id.match?(/\A\d+\z/)

    address = Address.find_by(id: raw_id.to_i, placeholder: [false, nil])
    return import_by_lgl_id(row, columns, seen_ids, outcome_with_message(:unmatched)) if address.nil?

    [apply_row(address, row, columns, seen_ids), nil]
  rescue StandardError => e
    Rails.logger.error("LglDonorImport: row failed - #{e.message}")
    [:error, ImportIssuesReport.format_exception(e)]
  end

  # A row whose External constituent ID is blank or matches no customer,
  # matched through the customer's LGL ID tag. Returns [outcome, message,
  # matched_by_lgl_id], or not_found when no customer carries the LGL id.
  def self.import_by_lgl_id(row, columns, seen_ids, not_found)
    lgl_id = columns[LGL_ID_HEADER] && row[columns[LGL_ID_HEADER]].to_s.strip
    return not_found unless lgl_id.to_s.match?(/\A\d+\z/)

    addresses = Lgl::Reconciler.tagged_addresses(lgl_id)
    return not_found if addresses.empty?
    return [:several_lgl_id, several_lgl_id_message(addresses)] if addresses.size > 1

    [apply_row(addresses.first, row, columns, seen_ids), nil, true]
  end

  def self.several_lgl_id_message(addresses)
    "#{LGL_ID_HEADER} is on customers #{addresses.map(&:id).join(', ')}: merge them"
  end

  def self.apply_row(address, row, columns, seen_ids)
    seen_ids << address.id
    apply_tiers(address, tier(row, columns[LAST_HEADER]), tier(row, columns[CURRENT_HEADER]))
  end

  def self.outcome_with_message(outcome)
    [outcome, ROW_MESSAGES.fetch(outcome)]
  end

  def self.tier(row, header)
    row[header].to_s.strip.presence
  end

  def self.apply_tiers(address, last_tier, current_tier)
    current = TIER_COLUMNS.map { |column| address.public_send(column).presence }
    return :unchanged if current == [last_tier, current_tier]

    address.update!(donor_tier_for_last_fiscal_year: last_tier, donor_tier_for_current_fiscal_year: current_tier)
    last_tier.nil? && current_tier.nil? ? :cleared : :updated
  end

  # Clears both tiers on every customer who has one but was not in the file.
  def self.clear_absent(seen_ids)
    with_tier = Address.where.not(donor_tier_for_last_fiscal_year: nil)
                       .or(Address.where.not(donor_tier_for_current_fiscal_year: nil))
    cleared = 0
    with_tier.in_batches(of: CLEAR_BATCH_SIZE) do |batch|
      absent_ids = batch.pluck(:id).reject { |id| seen_ids.include?(id) }
      next if absent_ids.empty?

      cleared += Address.where(id: absent_ids).update_all(TIER_COLUMNS.index_with { nil })
    end
    cleared
  end

  def self.summary(counts)
    "Donor levels: #{counts[:rows]} rows; updated #{counts[:updated]}, unchanged #{counts[:unchanged]}, " \
      "cleared #{counts[:cleared]}, matched by LGL ID #{counts[:by_lgl_id]}, no id #{counts[:blank_id]}, " \
      "errors #{error_count(counts)}; " \
      "cleared #{counts[:cleared_absent]} absent customers"
  end

  # Rows with an entry in the result file's Error column: an id that is not a
  # number, a number that matches no customer (nor by LGL id), an LGL id
  # tagged on several customers, or a row that could not be saved.
  def self.error_count(counts)
    counts[:error] + counts[:bad_id] + counts[:unmatched] + counts[:several_lgl_id]
  end

  # The result FileStore listing the rows with an Error entry, or nil when
  # no row had one.
  def self.write_results(filestore, problems)
    fs = problems.create(import_name: filestore.file_name, result_prefix: 'donor_import_results')
    fs&.save!
    fs
  end

  def self.notify_uploader(filestore, counts, result_file)
    if filestore.user.nil?
      Rails.logger.info("LglDonorImport: FileStore #{filestore.id} has no user; no completion email sent")
      return
    end

    NotificationMailer.donor_levels_imported(filestore, counts, result_file).deliver_now
  end
end
