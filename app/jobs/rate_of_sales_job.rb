class RateOfSalesJob < ApplicationJob
  @queue = :maintenance

  def self.perform
    calculate_for_day(Date.yesterday)
    RateOfSale.export_to_file(RateOfSale.export_records, RateOfSale.export_columns, File.join($SERVER_CONFIG['hud_export_directory'],'rate_of_sales.txt'))
  end

  def self.calculate_for_day(date)
    productions_with_sales = Production.joins(performances: :orders).where(orders: { created_at: date.all_day })

    productions_with_sales.each do |production|
      orders = TicketOrder.joins(:performance).where(performance: { production: production }, created_at: date.all_day)

      total_single_tickets = orders.sum(&:ticket_quantity) - orders.sum(&:complimentary_ticket_count)
      total_complimentary_tickets = orders.sum(&:complimentary_ticket_count)
      gross_sales = orders.sum(&:total_paid)
      processing_total = orders.sum(&:processing_fee)+orders.sum(&:ticketing_fee)

      rate_of_sale = RateOfSale.find_or_initialize_by(day_of_sale: date, production: production)

      rate_of_sale.update!(
        theater: production.theater,
        total_single_tickets: total_single_tickets,
        total_complimentary_tickets: total_complimentary_tickets,
        gross_sales: BigDecimal(gross_sales,2),
        processing_fees: BigDecimal(processing_total,2)
      )
    end
  end

  def self.calculate_last_30_days
    (1..30).each do |i|
      calculate_for_day(Date.today - i)
    end
  end
end
