namespace :rate_of_sales do
  desc 'Backfill the isolated ticketing_fees column on existing rate_of_sales rows'
  task backfill_ticketing_fees: :environment do
    # Recomputes ONLY the new ticketing_fees column for existing rows, using the
    # same RevenueCalculator path RateOfSalesJob.calculate_for_day uses. Other
    # columns (gross_sales, processing_fees, counts) are left untouched.
    #
    # Idempotent: re-running recomputes the same value for every row. By default
    # only rows still missing the column are processed; pass FORCE=1 to recompute
    # all rows (e.g. after a RevenueCalculator change).
    force = ENV['FORCE'].present?
    scope = RateOfSale.all
    scope = scope.where(ticketing_fees: nil) unless force

    total = scope.count
    mode = force ? ' (FORCE)' : ''
    puts "rate_of_sales:backfill_ticketing_fees: #{total} rows to process#{mode}"

    processed = 0
    errors = []
    scope.find_each.with_index do |ros, i|
      revenue = RevenueCalculator.for_production_on_day(ros.production_id, ros.day_of_sale)
      ros.update_columns(ticketing_fees: revenue.ticketing_fees)
      processed += 1
      print '.' if (i % 100).zero?
    rescue StandardError => e
      errors << "#{ros.id} (#{ros.production_id}/#{ros.day_of_sale}): #{e.message}"
      Rails.logger.warn "rate_of_sales:backfill_ticketing_fees: row #{ros.id} failed - #{e.message}"
    end

    puts "\nDone. Processed #{processed} rows, #{errors.size} errors."
    errors.each { |e| puts "  #{e}" } if errors.any?
  end
end
