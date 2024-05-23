# app/models/concerns/metrics_exporter.rb
module MetricsExporter
  extend ActiveSupport::Concern

  class_methods do
    # Exports a selection of records to a text file with specific formatting.
    #
    # @param records [ActiveRecord::Relation] ActiveRecord selection of records to export.
    # @param columns [Array<Symbol, Hash>] Array of column symbols or hash where key is the method and value is the header.
    # @param file_path [String] The file path where the output will be written.
    #
    # @example Exporting RateOfSale records
    #   records = RateOfSale.export_records
    #   columns = [:day_of_sale, :item_name, :quantity_sold, { production_id: "Production ID" }]
    #   file_path = 'rate_of_sale_metrics.txt'
    #   RateOfSale.export_to_file(records, columns, file_path)
    #
    # @return [void]
    def export_to_file(records, columns, file_path)
      formatted_lines = format_records(records, columns)
      File.open(file_path, 'w') do |file|
        formatted_lines.each { |line| file.puts(line) }
      end
    end

    private

    # Formats the records into lines for export.
    #
    # @param records [ActiveRecord::Relation] ActiveRecord selection of records to format.
    # @param columns [Array<Symbol, Hash>] Array of column symbols or hash where key is the method and value is the header.
    #
    # @return [Array<String>] An array of formatted lines for the output file.
    def format_records(records, columns)
      column_headers = columns.is_a?(Array) ? columns : columns.keys
      column_widths = column_headers.map do |column|
        header = format_header(column, columns)
        max_length = [header.length, *records.map { |record| record.send(column).to_s.length }].max
        max_length + 2 # for padding inside the cell
      end

      header = format_line(column_headers.map { |col| format_header(col, columns) }, column_widths)
      separator = '-' * (column_widths.sum + column_headers.size * 3 + 1) # +3 for each delimiter space and cell padding

      formatted_records = records.map do |record|
        values = column_headers.map do |column|
          value = record.send(column)
          column_width = column_widths[column_headers.index(column)]
          if value.is_a?(Numeric)
            value.to_s.rjust(column_width - 2) # -2 to account for the single space padding
          else
            value.to_s.ljust(column_width - 2) # -2 to account for the single space padding
          end
        end
        format_line(values, column_widths)
      end

      [separator, header, separator, *formatted_records, separator]
    end

    # Formats a single line for the output file.
    #
    # @param values [Array<String>] Array of values to format.
    # @param widths [Array<Integer>] Array of column widths for formatting.
    #
    # @return [String] A formatted line with columns separated by "|".
    def format_line(values, widths)
      values.zip(widths).map { |value, width| " #{value.ljust(width - 2)} " }.join('|').insert(0, '|').concat('|')
    end

    # Formats a header symbol into a human-readable string.
    #
    # @param header [Symbol] The header symbol to format.
    # @param columns [Array<Symbol, Hash>] The original columns array or hash to determine custom headers.
    #
    # @return [String] The formatted header string.
    #
    # @example
    #   format_header(:cpu_usage) # => "Cpu Usage"
    def format_header(header, columns)
      if columns.is_a?(Hash)
        columns[header] || header.to_s.split('_').map(&:capitalize).join(' ')
      else
        header.to_s.split('_').map(&:capitalize).join(' ')
      end
    end
  end
end
