namespace :orders do
  desc 'Transition held orders to processed for a given production code. ' \
       'Usage: bundle exec rake orders:process_held[PRAYER] ' \
       'or DRY_RUN=false bundle exec rake orders:process_held[PRAYER]'
  task :process_held, [:production_code] => :environment do |_t, args|
    production_code = args[:production_code]
    dry_run = ENV.fetch('DRY_RUN', 'true') != 'false'

    abort 'Usage: bundle exec rake orders:process_held[PRODUCTION_CODE]' if production_code.blank?

    production = Production.find_by(production_code: production_code)
    abort "Production '#{production_code}' not found." if production.nil?

    held_orders = production.ticket_orders.where(status: Order::HOLD)

    if held_orders.empty?
      puts "No orders in Hold status for production '#{production.name}' (#{production_code})."
      next
    end

    puts "Production: #{production.name} (#{production_code})"
    puts "Found #{held_orders.count} order(s) in Hold status"
    puts dry_run ? '** DRY RUN — no changes will be made **' : '** LIVE RUN — orders will be transitioned **'
    puts '-' * 60

    success = 0
    failed = 0

    held_orders.find_each do |order|
      perf = order.performance
      perf_label = begin
        "#{perf.performance_date} #{perf.performance_time.strftime('%l:%M %p')}"
      rescue StandardError
        "Perf ##{order.performance_id}"
      end
      line = "Order ##{order.id} | #{order.address&.full_name || 'No name'} | #{perf_label} | " \
             "Payment: #{order.payment_type&.display_name || 'None'} | Total: $#{'%.2f' % order.total}"

      if dry_run
        puts "  [DRY RUN] #{line}"
        success += 1
      else
        begin
          order.transition_to!(Order::PROCESSED)
          puts "  [OK] #{line}"
          success += 1
        rescue StandardError => e
          puts "  [FAIL] #{line}"
          puts "         Error: #{e.message}"
          failed += 1
        end
      end
    end

    puts '-' * 60
    if dry_run
      puts "Dry run complete. #{success} order(s) would be transitioned."
      puts 'Run with DRY_RUN=false to execute.'
    else
      puts "Done. #{success} succeeded, #{failed} failed."
    end
  end
end
