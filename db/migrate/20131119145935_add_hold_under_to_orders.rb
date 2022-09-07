class AddHoldUnderToOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :orders, :hold_under, :string
  end
end
