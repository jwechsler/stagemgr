class AddPrintOrderIdToOrders < ActiveRecord::Migration[4.2]
  def self.up
    add_column :orders, :print_order_id, :integer
  end

  def self.down
    remove_column :orders, :print_order_id
  end
end
