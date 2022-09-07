class AddGiftToOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :orders, :gift, :boolean, :default=>false
  end
end
