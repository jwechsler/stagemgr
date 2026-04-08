namespace :house_counts do
  desc "Backfill sold_out, near_capacity, and min_ticket_price for all house_counts"
  task backfill_calendar_fields: :environment do
    count = 0
    HouseCount.includes(performance: [:ticket_class_allocations, :production]).find_each do |hc|
      hc.calculate!
      count += 1
      print "." if count % 50 == 0
    end
    puts "\nDone. Updated #{count} house count records."
  end
end
