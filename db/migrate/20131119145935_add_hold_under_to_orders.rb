class AddHoldUnderToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :hold_under, :string
  end
end
