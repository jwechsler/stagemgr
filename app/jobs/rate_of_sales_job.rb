class RateOfSalesJob < ApplicationJob
  @queue = :maintenance
  
  include LoggedJob

  def self.perform(mode = nil)
    if mode == "today"
      calculate_for_today
    else
      calculate_for_day(Date.yesterday)
      RateOfSale.export_to_file(RateOfSale.export_records, RateOfSale.export_columns, File.join($SERVER_CONFIG['hud_export_directory'],'rate_of_sales.txt'))
    end
  end

  def self.calculate_for_today
    calculate_for_day(Date.current)
  end

  def self.calculate_for_day(date)
    orders_by_production = TicketOrder
      .joins(performance: :production)
      .includes(:payments, :ticket_line_items, :service_line_items)
      .where(created_at: date.all_day, status: Order::SETTLED_STATUSES)
      .group_by { |o| o.performance.production_id }

    orders_by_production.each do |production_id, orders|
      production = orders.first.performance.production

      total_tickets = 0
      total_comps = 0
      gross = 0.0
      fees = 0.0

      orders.each do |o|
        tlis = o.ticket_line_items.to_a
        total_tickets += tlis.sum(&:ticket_count)
        total_comps += tlis.select(&:complimentary?).sum(&:ticket_count)
        gross += o.payments.to_a.sum(&:amount)
        fees += o.processing_fee + o.ticketing_fee
      end

      total_tickets -= total_comps

      RateOfSale.find_or_initialize_by(day_of_sale: date, production_id: production_id).update!(
        total_single_tickets: total_tickets,
        total_complimentary_tickets: total_comps,
        gross_sales: CurrencyUtils.float_to_currency_decimal(gross),
        processing_fees: CurrencyUtils.float_to_currency_decimal(fees),
        order_count: orders.size
      )
    end
  end

  def self.calculate_last_30_days
    (1..30).each do |i|
      RateOfSalesJob.calculate_for_day(Date.today - i)
    end
  end

  def self.backfill_missing_days
    existing_dates = RateOfSale.distinct.pluck(:day_of_sale).to_set
    order_dates = Order.where(status: Order::SETTLED_STATUSES)
                       .distinct
                       .pluck(Arel.sql("DATE(created_at)"))
                       .map(&:to_date)
                       .sort

    missing = order_dates.reject { |d| existing_dates.include?(d) }
    Rails.logger.info "RateOfSalesJob.backfill_missing_days: #{missing.size} days to process"

    errors = []
    missing.each_with_index do |date, i|
      begin
        calculate_for_day(date)
      rescue => e
        errors << "#{date}: #{e.message}"
        Rails.logger.warn "RateOfSalesJob.backfill_missing_days: #{date} failed - #{e.message}"
      end
      print "." if i % 100 == 0
    end
    puts " Done! Processed #{missing.size} days, #{errors.size} errors."
    errors.each { |e| puts "  #{e}" } if errors.any?
    { processed: missing.size, errors: errors }
  end
end
