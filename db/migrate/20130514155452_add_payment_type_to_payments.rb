class AddPaymentTypeToPayments < ActiveRecord::Migration[4.2]
  def change
    add_column :payments, :payment_type_id, :integer
  end
end
