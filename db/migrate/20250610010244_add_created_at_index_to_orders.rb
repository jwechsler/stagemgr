class AddCreatedAtIndexToOrders < ActiveRecord::Migration[6.1]
  def change
    add_index :orders, :created_at, name: 'index_orders_on_created_at'
  end
end
