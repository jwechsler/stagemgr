class AddPaymentConstraints < ActiveRecord::Migration
  def change
    add_index :payments, :order_id
    add_foreign_key :payments, :orders, on_delete: :cascade
  end
end
