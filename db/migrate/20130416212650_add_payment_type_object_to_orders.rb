class AddPaymentTypeObjectToOrders < ActiveRecord::Migration
  def change
    rename_column :orders, :payment_type, :payment_type_id
  end

end
