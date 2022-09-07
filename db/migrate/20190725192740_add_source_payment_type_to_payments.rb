class AddSourcePaymentTypeToPayments < ActiveRecord::Migration[4.2]
  def change
    add_column :payments, :source_payment_type_id, :int
  end
end
