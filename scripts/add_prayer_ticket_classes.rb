# Run in Rails console:
#   load 'scripts/add_prayer_ticket_classes.rb'
#
# This script adds TicketClass records to the PRAYER production
# from the TicketClass_Summary CSV data. Each ticket class is created
# with auto_attach: true, which triggers automatic creation of
# TicketClassAllocations for all existing PRAYER performances.

production = Production.find_by!(production_code: 'PRAYER')

ticket_data = [
  ['COMP', 0.00],
  ['EXTERNAL10', 10.00],
  ['EXTERNAL13', 13.00],
  ['EXTERNAL15', 15.00],
  ['EXTERNAL16', 15.50],
  ['EXTERNAL18', 18.00],
  ['EXTERNAL20', 20.00],
  ['EXTERNAL22', 22.50],
  ['EXTERNAL24', 24.50],
  ['EXTERNAL26', 26.50],
  ['EXTERNAL28', 27.50],
  ['EXTERNAL29', 28.60],
  ['EXTERNAL30', 29.50],
  ['EXTERNAL31', 31.00],
  ['EXTERNAL32', 32.00],
  ['EXTERNAL33', 33.00],
  ['EXTERNAL34', 34.50],
  ['EXTERNAL35', 35.00],
  ['EXTERNAL36', 35.50],
  ['EXTERNAL37', 36.60],
  ['EXTERNAL38', 38.00],
  ['EXTERNAL39', 39.00],
  ['EXTERNAL40', 40.00],
  ['EXTERNAL41', 41.40],
  ['EXTERNAL42', 42.00],
  ['EXTERNAL43', 42.60],
  ['EXTERNAL44', 44.00],
  ['EXTERNAL45', 45.00],
  ['EXTERNAL46', 46.00],
  ['EXTERNAL47', 47.00],
  ['EXTERNAL48', 48.40],
  ['EXTERNAL49', 49.00],
  ['EXTERNAL51', 51.00],
  ['EXTERNAL52', 52.00],
  ['EXTERNAL53', 52.90],
  ['EXTERNAL54', 54.00],
  ['EXTERNAL55', 55.00],
  ['EXTERNAL56', 56.00],
  ['EXTERNAL57', 57.00],
  ['EXTERNAL58', 58.00],
  ['EXTERNAL59', 59.00],
  ['EXTERNAL61', 61.00],
  ['EXTERNAL62', 62.00],
  ['EXTERNAL63', 63.00],
  ['EXTERNAL64', 64.00],
  ['EXTERNAL65', 65.00],
  ['EXTERNAL66', 66.00],
  ['EXTERNAL67', 67.00],
  ['EXTERNAL68', 68.00],
  ['EXTERNAL69', 69.00],
  ['EXTERNAL71', 71.00],
  ['EXTERNAL72', 72.00],
  ['EXTERNAL73', 73.00],
  ['EXTERNAL74', 74.00],
  ['EXTERNAL75', 75.00],
  ['EXTERNAL76', 76.00],
  ['EXTERNAL77', 77.00],
  ['EXTERNAL78', 78.00],
  ['EXTERNAL79', 79.00],
  ['EXTERNAL81', 81.00],
  ['EXTERNAL82', 82.00],
  ['EXTERNAL83', 83.00],
  ['EXTERNAL84', 84.00],
  ['EXTERNAL86', 86.00],
  ['EXTERNAL87', 87.00],
  ['EXTERNAL88', 88.00],
  ['EXTERNAL89', 89.00],
  ['EXTERNAL91', 91.00]
]

created = []
skipped = []
errors = []

ActiveRecord::Base.transaction do
  ticket_data.each do |class_code, price|
    # Skip if this ticket class already exists for PRAYER
    if production.ticket_classes.exists?(class_code: class_code)
      skipped << class_code
      next
    end

    is_comp = (class_code == 'COMP')

    tc = production.ticket_classes.build(
      class_code: class_code,
      class_name: is_comp ? 'Complimentary' : class_code,
      ticket_type: 'Fixed',
      ticket_price: price,
      ticketing_fee: 0.0,
      auto_attach: true,
      web_visible: false,
      holds_seats: true,
      complimentary: is_comp,
      show_in_pricing_range: !is_comp
    )

    if tc.save
      created << "#{class_code} ($#{'%.2f' % price})"
    else
      errors << "#{class_code}: #{tc.errors.full_messages.join(', ')}"
    end
  end

  # Abort transaction if there were any errors
  if errors.any?
    puts "\n*** ERRORS - rolling back all changes ***"
    errors.each { |e| puts "  #{e}" }
    raise ActiveRecord::Rollback
  end
end

puts "\n=== PRAYER Ticket Class Import ==="
puts "Created: #{created.size}"
created.each { |c| puts "  + #{c}" }

if skipped.any?
  puts "Skipped (already exist): #{skipped.size}"
  skipped.each { |s| puts "  - #{s}" }
end

if errors.any?
  puts "Errors: #{errors.size}"
  errors.each { |e| puts "  ! #{e}" }
  puts "\n*** No records were saved due to errors ***"
else
  perf_count = production.performances.count
  puts "\nAuto-attached to #{perf_count} performance(s)"
  puts 'Done!'
end
