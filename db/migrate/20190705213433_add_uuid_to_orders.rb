class AddUuidToOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :orders, :uuid, :string
    add_index :orders, :uuid, unique: true
  end
end
