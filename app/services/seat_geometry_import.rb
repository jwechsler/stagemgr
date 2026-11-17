require 'csv'

# Imports seat geometry for a seat map from a CSV file (the "Seating Geometry
# File" on the admin seat map form). A row whose location matches a seat on the
# map updates that seat; any other row adds a seat. A location repeated in the
# file is applied row by row, so the later row wins.
#
#   import = SeatGeometryImport.new(seat_map, uploaded_file)
#   import.check  # => Result; reads the file, changes nothing
#   import.call   # => Result; imports unless check found a problem
#
# A file that cannot be parsed, is empty or lacks a required column imports
# nothing. Otherwise each row is saved on its own, and rows whose seat fails
# validation are reported in Result#skipped_rows rather than stopping the run.
class SeatGeometryImport
  REQUIRED_HEADERS = %w[location row sequence origin-x origin-y width height feature].freeze
  # When the zone column is absent, existing seat zones are left untouched.
  # When present and blank, the seat resets to the default zone
  # (Seat#normalize_zone).
  OPTIONAL_HEADERS = %w[zone].freeze

  COLUMN_ATTRIBUTES = {
    'row' => :row,
    'sequence' => :seat_number,
    'origin-x' => :origin_x,
    'origin-y' => :origin_y,
    'width' => :width,
    'height' => :height,
    'feature' => :feature
  }.freeze

  # Header names are compared with anything outside ASCII removed (a byte
  # order mark on the first header) and surrounding whitespace trimmed.
  ASCII_ONLY = { invalid: :replace, undef: :replace, replace: '' }.freeze
  HEADER_CONVERTER = ->(header) { header.to_s.encode(Encoding::US_ASCII, **ASCII_ONLY).strip }

  # The skipped-row list travels in the flash, which lives in the cookie
  # session, so only the first few rows are listed.
  MAX_LISTED_SKIPPED_ROWS = 10
  MAX_LOCATION_LENGTH = 20

  SkippedRow = Struct.new(:line, :location, :reason, keyword_init: true) do
    def to_s
      label = location.present? ? "location #{location.truncate(MAX_LOCATION_LENGTH)}" : 'no location'
      "line #{line} (#{label}): #{reason}"
    end
  end

  Result = Struct.new(:filename, :read_error, :missing_headers, :imported_count, :skipped_rows,
                      keyword_init: true) do
    # True when the file was read and has every required column.
    def importable?
      read_error.nil? && missing_headers.empty?
    end

    # Plain-text message explaining why nothing was imported, or nil.
    def problem_message
      return read_error if read_error
      return if missing_headers.empty?

      "The geometry file is missing required column(s): #{missing_headers.join(', ')}. " \
        "Nothing was imported. Required columns: #{REQUIRED_HEADERS.join(', ')}."
    end

    def summary_message
      "Imported #{imported_count} #{'seat'.pluralize(imported_count)} from #{filename}."
    end

    # Plain-text list of skipped rows (capped), or nil when none were skipped.
    def skipped_message
      return if skipped_rows.empty?

      listed = skipped_rows.first(MAX_LISTED_SKIPPED_ROWS).map(&:to_s)
      remaining = skipped_rows.size - listed.size
      listed << "and #{remaining} more" if remaining.positive?
      "#{skipped_rows.size} #{skipped_rows.size == 1 ? 'row was' : 'rows were'} skipped: #{listed.join('; ')}"
    end
  end

  def initialize(seat_map, source)
    @seat_map = seat_map
    @source = source
  end

  def check
    @check ||= begin
      parse
      @headers.empty? ? empty_file_result : build_result(missing_headers: missing_headers)
    rescue CSV::MalformedCSVError => e
      Rails.logger.warn("SeatGeometryImport: #{filename} for seat map #{@seat_map.id}: #{e.message}")
      line = e.line_number ? " (line #{e.line_number})" : ''
      build_result(read_error: "The geometry file could not be read as a CSV file#{line}. Nothing was imported.")
    end
  end

  def call
    return check unless check.importable?

    imported, skipped = import_rows
    @seat_map.seats.reset
    build_result(imported_count: imported.size, skipped_rows: skipped)
  end

  private

  def filename
    name = @source.respond_to?(:original_filename) ? @source.original_filename : nil
    name.presence || File.basename(source_path.to_s).presence || 'the geometry file'
  end

  def source_path
    @source.is_a?(String) ? @source : (@source.path if @source.respond_to?(:path))
  end

  def read_source
    path = source_path
    path ? File.read(path) : @source.read
  end

  # Reads the whole file up front (geometry files are a few hundred rows) so a
  # malformed line anywhere stops the import before any seat is touched.
  # Rows are kept with their line number, the header being line 1.
  def parse
    return if @rows

    csv = CSV.new(read_source, headers: true, header_converters: HEADER_CONVERTER)
    rows = []
    csv.each { |row| rows << [csv.lineno, row] unless row.fields.all?(&:blank?) }
    @headers = csv.headers.is_a?(Array) ? csv.headers : []
    @rows = rows
  end

  def missing_headers
    REQUIRED_HEADERS - @headers
  end

  def empty_file_result
    build_result(read_error: 'The geometry file is empty. Nothing was imported.')
  end

  def build_result(read_error: nil, missing_headers: [], imported_count: 0, skipped_rows: [])
    Result.new(filename: filename, read_error: read_error, missing_headers: missing_headers,
               imported_count: imported_count, skipped_rows: skipped_rows)
  end

  # Returns the locations saved and the rows skipped.
  def import_rows
    seats_by_location = @seat_map.seats.reload.index_by(&:location)
    imported = Set.new
    skipped = []
    @rows.each do |line, row|
      seat = apply_row(seats_by_location, row)
      if seat.save
        imported << seat.location
      else
        skipped << SkippedRow.new(line: line, location: row['location'], reason: seat.errors.full_messages.to_sentence)
      end
    end
    [imported, skipped]
  end

  def apply_row(seats_by_location, row)
    location = row['location']
    seat = seats_by_location[location] || Seat.new(seat_map_id: @seat_map.id, location: location)
    seats_by_location[location] = seat if location.present?
    seat.assign_attributes(COLUMN_ATTRIBUTES.to_h { |column, attribute| [attribute, row[column]] })
    seat.zone = row['zone'] if @headers.include?('zone')
    seat
  end
end
