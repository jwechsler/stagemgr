class RateOfSalesJob
  @queue = :maintenance

  def self.perform
    calculate_for_day(Date.yesterday)
  end

  def self.calculate_for_day(date)
    productions_with_sales = Production.joins(performances: :orders).where(orders: { created_at: date.all_day })

    productions_with_sales.each do |production|
      orders = TicketOrder.joins(:performance).where(performance: { production: production }, created_at: date.all_day)

      total_single_tickets = orders.sum(&:ticket_quantity) - orders.sum(&:complimentary_ticket_count)
      total_complimentary_tickets = orders.sum(&:complimentary_ticket_count)
      gross_sales = orders.sum(&:total_revenue)
      processing_fees = orders.sum(&:processing_fee)

      rate_of_sale = RateOfSale.find_or_initialize_by(day_of_sale: date, production: production)

      rate_of_sale.update!(
        theater: production.theater,
        total_single_tickets: total_single_tickets,
        total_complimentary_tickets: total_complimentary_tickets,
        gross_sales: gross_sales,
        processing_fees: processing_fees
      )
    end
  end

  def self.back_calculate_last_30_days
    (1..30).each do |i|
      calculate_for_day(Date.today - i)
    end
  end
end
