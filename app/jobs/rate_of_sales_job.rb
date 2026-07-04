class RateOfSalesJob < ApplicationJob
  @queue = :maintenance

  include LoggedJob

  # Each run recomputes the prior 30 days so refunds and exchanges that land
  # on an older order self-heal the stale snapshot within a month. Older days
  # stay frozen.
  SELF_HEAL_WINDOW_DAYS = 30

  def self.perform(mode = nil)
    if mode == 'today'
      calculate_for_today
    else
      calculate_recent_days(Date.yesterday, SELF_HEAL_WINDOW_DAYS)
      RateOfSale.export_to_file(RateOfSale.export_records, RateOfSale.export_columns,
                                File.join(Rails.configuration.x.server_config['hud_export_directory'], 'rate_of_sales.txt'))
    end
  end

  def self.calculate_for_today
    calculate_for_day(Date.current)
  end

  def self.calculate_recent_days(end_date, window_days)
    (0...window_days).each { |i| calculate_for_day(end_date - i) }
  end

  def self.calculate_for_day(date)
    production_ids = TicketOrder
                     .joins(:performance)
                     .where(created_at: date.all_day, status: Order::SETTLED_STATUSES)
                     .distinct
                     .pluck('performances.production_id')

    production_ids.each do |production_id|
      revenue = RevenueCalculator.for_production_on_day(production_id, date)

      RateOfSale.find_or_initialize_by(day_of_sale: date, production_id: production_id).update!(
        total_single_tickets: revenue.ticket_count,
        total_complimentary_tickets: revenue.comp_count,
        gross_sales: revenue.collected,
        # Legacy combined figure (ticketing + processing). Kept as-is for
        # backward compatibility; the isolated ticketing portion now also lives
        # in the dedicated ticketing_fees column below.
        processing_fees: revenue.ticketing_fees + revenue.processing_fees,
        ticketing_fees: revenue.ticketing_fees,
        order_count: revenue.order_count
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
                       .pluck(Arel.sql('DATE(created_at)'))
                       .map(&:to_date)
                       .sort

    missing = order_dates.reject { |d| existing_dates.include?(d) }
    Rails.logger.info "RateOfSalesJob.backfill_missing_days: #{missing.size} days to process"

    errors = []
    missing.each_with_index do |date, i|
      begin
        calculate_for_day(date)
      rescue StandardError => e
        errors << "#{date}: #{e.message}"
        Rails.logger.warn "RateOfSalesJob.backfill_missing_days: #{date} failed - #{e.message}"
      end
      print '.' if i % 100 == 0
    end
    puts " Done! Processed #{missing.size} days, #{errors.size} errors."
    errors.each { |e| puts "  #{e}" } if errors.any?
    { processed: missing.size, errors: errors }
  end
end
