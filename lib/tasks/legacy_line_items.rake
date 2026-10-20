namespace :legacy_line_items do
  desc 'Split aggregated seat line items left by CSV bulk order imports before 2026-10-01 into per-seat items ' \
       'on upcoming reserved-seating orders (DRY_RUN=1 to preview)'
  task split_aggregates: :environment do
    # LEGACY backfill: see LegacyAggregateSplitter. Idempotent -- an order
    # already split has no aggregate left and is not selected again.
    dry_run = ENV['DRY_RUN'].present?
    scope = LegacyAggregateSplitter.candidate_orders
    puts "legacy_line_items:split_aggregates: #{scope.count} order(s) to process#{' (DRY_RUN)' if dry_run}"

    totals = Hash.new(0)
    seats_split = 0
    errors = []
    scope.find_each do |order|
      result = LegacyAggregateSplitter.new(order, dry_run: dry_run).call
      puts "  #{result}"
      totals[result.status] += 1
      seats_split += result.seats_split
    rescue StandardError => e
      errors << "Order #{order.id}: #{e.message}"
      Rails.logger.warn "legacy_line_items:split_aggregates: order #{order.id} failed - #{e.message}"
    end

    summary = totals.map { |status, count| "#{count} #{status}" }.join(', ')
    verb = dry_run ? 'would be split' : 'split'
    puts "Done. #{summary.presence || 'no orders'}; #{seats_split} seat(s) #{verb}; #{errors.size} error(s)."
    errors.each { |e| puts "  #{e}" }
  end
end
