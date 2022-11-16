class AddPaymentTypeObjectToOrders < ActiveRecord::Migration[4.2]
  def change
    rename_column :orders, :payment_type, :payment_type_id
  end

end
