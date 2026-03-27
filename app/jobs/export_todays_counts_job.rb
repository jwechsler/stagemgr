class ExportTodaysCountsJob
  @queue = :report

  def self.perform
    rate_of_sales = RateOfSale.where(day_of_sale: Date.current)
                              .includes(:production)
                              .order('productions.name')

    rows = rate_of_sales.map do |ros|
      {
        sold_on: ros.day_of_sale.strftime('%Y-%m-%d'),
        name: ros.production.name[0, 24],
        orders: ros.order_count.to_s,
        num_sold: (ros.total_single_tickets + ros.total_complimentary_tickets).to_s,
        amount: format_currency(ros.gross_sales)
      }
    end

    columns = [
      { key: :sold_on, header: "sold_on", align: :left },
      { key: :name, header: "name", align: :left },
      { key: :orders, header: "orders", align: :right },
      { key: :num_sold, header: "num_sold", align: :right },
      { key: :amount, header: "Amount", align: :right }
    ]

    content = HudTableFormatter.render(
      columns: columns,
      rows: rows,
      footer: "Generated #{Time.current.strftime('%a %b %d %H:%M:%S %Z %Y')}"
    )

    file_path = File.join($SERVER_CONFIG['hud_export_directory'], 'todays_counts.txt')
    HudTableFormatter.write_to_file(content, file_path)
  end

  private

  def self.format_currency(amount)
    # Format with 2 decimal places and comma thousands separator
    # e.g., 4803.80 -> "4,803.80", 20.0 -> "20.00"
    parts = format('%.2f', amount).split('.')
    parts[0] = parts[0].gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
    parts.join('.')
  end
end
