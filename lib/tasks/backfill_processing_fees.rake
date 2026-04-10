namespace :payments do
  desc "Backfill processing_fee for all payment records"
  task backfill_processing_fees: :environment do
    cutoff = '2021-07-16'

    # CreditCardPayments after cutoff with positive amount: $0.30 + 3.5%
    post_cutoff = Payment.where(type: 'CreditCardPayment', processing_fee: nil)
      .where('created_at > ? AND amount > 0', cutoff)
      .update_all("processing_fee = ROUND(0.30 + amount * 0.035, 2)")
    puts "CreditCardPayment (post-#{cutoff}): #{post_cutoff} updated"

    # CreditCardPayments before cutoff with positive amount: $0.22 + 4%
    pre_cutoff = Payment.where(type: 'CreditCardPayment', processing_fee: nil)
      .where('created_at <= ? AND amount > 0', cutoff)
      .update_all("processing_fee = ROUND(0.22 + amount * 0.04, 2)")
    puts "CreditCardPayment (pre-#{cutoff}): #{pre_cutoff} updated"

    # CreditCardPayments with non-positive amount (refunds): $0
    cc_refunds = Payment.where(type: 'CreditCardPayment', processing_fee: nil)
      .where('amount <= 0')
      .update_all(processing_fee: 0)
    puts "CreditCardPayment (refunds): #{cc_refunds} updated"

    # RecurringPayments: $0.22 + 2.2%
    recurring = Payment.where(type: 'RecurringPayment', processing_fee: nil)
      .update_all("processing_fee = ROUND(0.22 + amount * 0.022, 2)")
    puts "RecurringPayment: #{recurring} updated"

    # All other payment types: $0
    other = Payment.where(processing_fee: nil)
      .update_all(processing_fee: 0)
    puts "Other payment types: #{other} updated"

    remaining = Payment.where(processing_fee: nil).count
    puts "\nDone. Remaining un-backfilled: #{remaining}"
  end
end
