class AddUuidToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :uuid, :string
    add_index :orders, :uuid, unique:true
  end
end
