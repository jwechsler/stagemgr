require "fileutils"

class HudTableFormatter
  # Renders a MySQL --table=true style fixed-width text table.
  #
  # columns: Array of hashes with keys:
  #   :key    — symbol used to look up the value in each row hash
  #   :header — string shown in the header row
  #   :align  — :left or :right
  #
  # rows: Array of hashes; values should already be formatted strings.
  #
  # title:  Optional string printed above the table.
  # footer: Optional string printed below the table.
  #
  # Returns the formatted table as a String (no trailing newline).
  def self.render(columns:, rows:, title: nil, footer: nil)
    col_widths = compute_widths(columns, rows)

    lines = []
    lines << title if title

    separator = build_separator(col_widths)
    lines << separator
    lines << build_row(columns, col_widths) { |col| col[:header] }
    lines << separator

    rows.each do |row|
      lines << build_row(columns, col_widths) { |col| row[col[:key]].to_s }
    end

    lines << separator
    lines << footer if footer

    lines.join("\n")
  end

  # Atomically writes content to file_path by writing to a .tmp file first,
  # then moving it into place.
  def self.write_to_file(content, file_path)
    tmp_path = "#{file_path}.tmp"
    File.write(tmp_path, content)
    FileUtils.mv(tmp_path, file_path)
  end

  private

  # Returns an array of integers: the total column width (including the two
  # padding spaces) for each column, in order.
  def self.compute_widths(columns, rows)
    columns.map do |col|
      max_value_len = rows.map { |row| row[col[:key]].to_s.length }.max || 0
      [col[:header].length, max_value_len].max + 2
    end
  end

  # Builds a separator line like: +------+--------+
  def self.build_separator(col_widths)
    "+#{col_widths.map { |w| "-" * w }.join("+")}+"
  end

  # Builds a data or header row.  The block receives each column definition
  # and must return the string value to display.
  def self.build_row(columns, col_widths, &value_for)
    cells = columns.each_with_index.map do |col, i|
      inner_width = col_widths[i] - 2 # subtract the two padding spaces
      value = value_for.call(col)
      padded = case col[:align]
               when :right then value.rjust(inner_width)
               else             value.ljust(inner_width)
               end
      " #{padded} "
    end
    "|#{cells.join("|")}|"
  end
end
