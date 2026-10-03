class AddReviewColumnsToOrders < ActiveRecord::Migration[6.1]
  # An order flagged for box office review (ReviewFlaggable), e.g. after a
  # refund made in the Stripe dashboard changed its money. The orders listing
  # filters on review_flagged_at / reviewed_at alone, never on a live balance.
  def change
    change_table :orders, bulk: true do |t|
      t.string :review_reason
      t.datetime :review_flagged_at
      t.datetime :reviewed_at
      t.integer :reviewed_by_id
      t.text :review_note
      t.index :review_flagged_at
    end
  end
end
