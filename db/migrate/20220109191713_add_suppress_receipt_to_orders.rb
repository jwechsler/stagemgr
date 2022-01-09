class AddSuppressReceiptToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :suppress_receipt, :boolean, default: false
  end
end
