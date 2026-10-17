class AddLglGiftIdToOrders < ActiveRecord::Migration[6.1]
  # The LGL gift id a replicated donation was written as; the idempotency key
  # that keeps a donation from being sent to LGL twice.
  def change
    add_column :orders, :lgl_gift_id, :bigint
    add_index :orders, :lgl_gift_id
  end
end
