# app/jobs/export_house_counts_job.rb
class ExportHouseCountsJob
  @queue = :report

  def self.file_path
    File.join($SERVER_CONFIG['hud_export_directory'], 'house_counts.txt')
  end

  def self.perform(file_path = nil)
    columns = [
      { key: :code,      header: 'Code',      align: :left  },
      { key: :sold,      header: 'Sold',      align: :right },
      { key: :held,      header: 'Held',      align: :right },
      { key: :remaining, header: 'Remaining', align: :right },
      { key: :max_price, header: 'Max Price', align: :right }
    ]

    rows = HouseCount.export_records.map do |house_count|
      max_price = house_count.max_ticket_price
      {
        code: house_count.performance.performance_code,
        sold: house_count.sold_seats.to_s,
        held: house_count.held_seats.to_s,
        remaining: house_count.available_seats.to_s,
        max_price: max_price ? format('%.2f', max_price) : ''
      }
    end

    content = HudTableFormatter.render(
      columns: columns,
      rows: rows,
      title: 'HOUSE COUNTS',
      footer: "Generated #{Time.current.strftime('%a %b %d %H:%M:%S %Z %Y')}"
    )

    HudTableFormatter.write_to_file(content, file_path || self.file_path)
  end
end
