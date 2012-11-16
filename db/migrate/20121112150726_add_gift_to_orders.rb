class AddGiftToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :gift, :boolean, :default=>false
  end
end
