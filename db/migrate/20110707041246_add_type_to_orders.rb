class AddTypeToOrders < ActiveRecord::Migration[4.2]
  def self.up
    add_column :orders, :type, :string, :default => 'Order'
  end

  def self.down
    remove_column :orders, :type
  end
end
