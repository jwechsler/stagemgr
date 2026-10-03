class AddStripeRefundIdToPayments < ActiveRecord::Migration[6.1]
  # The Stripe refund (re_...) a refund row records. Unique, so a webhook
  # delivered twice cannot book the same dashboard refund twice, and a refund
  # the app issued itself is recognised when Stripe reports it back.
  def change
    add_column :payments, :stripe_refund_id, :string
    add_index :payments, :stripe_refund_id, unique: true
  end
end
