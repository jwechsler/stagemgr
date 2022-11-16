class AddRecipientToOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :orders, :recipient_name, :string
    add_column :orders, :recipient_email, :string
    add_column :orders, :gift_date, :date
  end
end
