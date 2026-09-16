class RedateBackdatedFullRefundPayments < ActiveRecord::Migration[6.1]
  # Full refunds (Order#refund! -> Payment#create_refund_payment and
  # CreditCardPayment#refund!) built the refund row with #dup, which copied
  # processed_on from the original tender. Daily Receipts buckets payments by
  # processed_on, so every full refund was reported on the day of the original
  # sale instead of the day it was issued. Payment#dup_for_refund fixes new
  # rows; this moves the existing ones to the moment they were actually written.
  #
  # Scope is deliberately narrow:
  #   * only the dup-built tender types (RefundPayment, ReversalPayment,
  #     ExchangePayment and PriceOverridePayment were never dup'd, and
  #     RecurringPayment sets processed_on on purpose);
  #   * only orders that ended up Refunded, so split-order offsets (also dup'd,
  #     but paired with a positive row on the split order at the same date) keep
  #     their pairing;
  #   * a negative row with a mirror-image positive row written on another
  #     order within 5 seconds is such a split pair and is skipped even on a
  #     Refunded order.
  # Status string is literal on purpose; migrations shouldn't depend on app constants.
  #
  # Ids are selected first and updated by id: MySQL refuses an UPDATE whose
  # subquery reads the table being updated (error 1093). Ran in under a second
  # against a full-size copy of the production database.
  def up
    ids = select_values(<<~SQL.squish)
      SELECT p.id
      FROM payments p
      JOIN orders o ON o.id = p.order_id
      WHERE p.amount < 0
        AND p.type IN ('CreditCardPayment', 'CashPayment', 'MembershipPayment', 'FlexPassPayment')
        AND o.status = 'Refunded'
        AND p.processed_on < p.created_at - INTERVAL 1 HOUR
        AND NOT EXISTS (
          SELECT 1 FROM payments q
          WHERE q.order_id <> p.order_id
            AND q.type = p.type
            AND q.amount = -p.amount
            AND ABS(TIMESTAMPDIFF(SECOND, q.created_at, p.created_at)) <= 5
        )
    SQL

    moved = 0
    ids.each_slice(500) do |slice|
      moved += update("UPDATE payments SET processed_on = created_at WHERE id IN (#{slice.join(',')})")
    end
    say "Re-dated #{moved} full-refund payment rows to their creation time"
  end

  def down
    # The original processed_on values were copies of the refunded tender's
    # date and are not recoverable once overwritten.
    raise ActiveRecord::IrreversibleMigration
  end
end
