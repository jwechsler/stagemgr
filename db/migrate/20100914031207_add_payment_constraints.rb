class AddPaymentConstraints < ActiveRecord::Migration[4.2]
  def change
    add_index :payments, :order_id
    add_foreign_key :payments, :orders, on_delete: :cascade
  end
end
