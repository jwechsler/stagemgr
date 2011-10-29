class AddPrintOrderIdToOrders < ActiveRecord::Migration
  def self.up
    add_column :orders, :print_order_id, :integer
  end

  def self.down
    remove_column :orders, :print_order_id
  end
end
