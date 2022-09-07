class AddSuppressReceiptToOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :orders, :suppress_receipt, :boolean, default: false
  end
end
