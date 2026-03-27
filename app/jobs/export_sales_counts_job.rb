class ExportSalesCountsJob
  @queue = :report

  def self.file_path(period)
    filename = case period
               when 'last7'     then 'last7_counts.txt'
               when 'previous7' then 'previous7_counts.txt'
               end
    File.join($SERVER_CONFIG['hud_export_directory'], filename)
  end

  def self.perform(period = 'last7', file_path = nil)
    date_range = case period
                 when 'last7'
                   7.days.ago.to_date..Date.yesterday
                 when 'previous7'
                   14.days.ago.to_date..8.days.ago.to_date
                 else
                   raise ArgumentError, "Unknown period: #{period}"
                 end

    # Get RateOfSale records for the date range, grouped by production
    rate_of_sales = RateOfSale.where(day_of_sale: date_range)
                              .includes(:production)

    # Aggregate by production
    by_production = rate_of_sales.group_by(&:production)

    rows = by_production.map do |production, sales|
      {
        name:     production.name[0, 24],
        orders:   sales.sum(&:order_count).to_s,
        num_sold: sales.sum { |s| s.total_single_tickets + s.total_complimentary_tickets }.to_s,
        amount:   format_currency(sales.sum(&:gross_sales))
      }
    end.sort_by { |r| r[:name] }

    columns = [
      { key: :name,     header: 'name',     align: :left  },
      { key: :orders,   header: 'orders',   align: :right },
      { key: :num_sold, header: 'num_sold', align: :right },
      { key: :amount,   header: 'Amount',   align: :right }
    ]

    # Note: last7 and previous7 samples have NO title and NO footer
    content = HudTableFormatter.render(
      columns: columns,
      rows:    rows
    )

    HudTableFormatter.write_to_file(content, file_path || self.file_path(period))
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
