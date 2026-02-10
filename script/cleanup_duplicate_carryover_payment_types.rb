# Cleanup duplicate PriceOverridePaymentType ("Carryover") records
#
# The PriceOverridePayment#payment_type method previously used inconsistent
# attribute sets in find_or_create_by calls, creating duplicate
# PriceOverridePaymentType records that all display as "Carryover".
#
# This script consolidates them: one record per unique
# (report_as_sales_collected, report_as_production_revenue) combination,
# reassigns all payments to the canonical record, and deletes the duplicates.
#
# Usage: bundle exec rails runner script/cleanup_duplicate_carryover_payment_types.rb
#        Add DRY_RUN=1 to preview changes without modifying data.

dry_run = ENV['DRY_RUN'] == '1'
puts dry_run ? "=== DRY RUN MODE ===" : "=== LIVE RUN ==="

all_overrides = PriceOverridePaymentType.all.to_a
puts "\nFound #{all_overrides.size} PriceOverridePaymentType records:"
all_overrides.each do |pt|
  payments = Payment.where(payment_type_id: pt.id).count
  puts "  id=#{pt.id}  report_sales=#{pt[:report_as_sales_collected]}  " \
       "report_rev=#{pt[:report_as_production_revenue]}  " \
       "allow_box=#{pt[:allow_for_box_office]}  " \
       "payments=#{payments}"
end

if all_overrides.size <= 1
  puts "\nNo duplicates found. Nothing to do."
  exit
end

# Group by the attributes that should distinguish records
groups = all_overrides.group_by { |pt|
  [pt[:report_as_sales_collected], pt[:report_as_production_revenue]]
}

total_reassigned = 0
total_deleted = 0

groups.each do |(report_sales, report_rev), records|
  # Pick the canonical record: prefer one that already has allow_for_box_office: false,
  # otherwise use the one with the lowest id
  canonical = records.find { |r| r[:allow_for_box_office] == false } || records.min_by(&:id)
  duplicates = records - [canonical]

  puts "\nGroup (report_sales=#{report_sales}, report_rev=#{report_rev}):"
  puts "  Keeping id=#{canonical.id} as canonical"
  puts "  Duplicates to remove: #{duplicates.map(&:id).join(', ')}" if duplicates.any?

  # Ensure canonical record has correct attributes
  unless canonical[:allow_for_box_office] == false
    puts "  Updating canonical id=#{canonical.id}: allow_for_box_office -> false"
    canonical.update_column(:allow_for_box_office, false) unless dry_run
  end

  duplicates.each do |dup|
    payment_ids = Payment.where(payment_type_id: dup.id).pluck(:id)
    if payment_ids.any?
      puts "  Reassigning #{payment_ids.size} payments from id=#{dup.id} to id=#{canonical.id} " \
           "(payment ids: #{payment_ids.join(', ')})"
      unless dry_run
        Payment.where(payment_type_id: dup.id).update_all(payment_type_id: canonical.id)
      end
      total_reassigned += payment_ids.size
    end

    puts "  Deleting PriceOverridePaymentType id=#{dup.id}"
    unless dry_run
      # Bypass the prevent_orphans callback since we already reassigned payments
      dup.delete
    end
    total_deleted += 1
  end
end

puts "\n=== Summary ==="
puts "Payments reassigned: #{total_reassigned}"
puts "PriceOverridePaymentType records deleted: #{total_deleted}"
puts "PriceOverridePaymentType records remaining: #{dry_run ? all_overrides.size - total_deleted : PriceOverridePaymentType.count}"
puts dry_run ? "\nThis was a dry run. Run without DRY_RUN=1 to apply changes." : "\nDone."
