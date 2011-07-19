class AddTypeToOrders < ActiveRecord::Migration
  def self.up
    add_column :orders, :type, :string, :default => 'Order'
  end

  def self.down
    remove_column :orders, :type
  end
end
