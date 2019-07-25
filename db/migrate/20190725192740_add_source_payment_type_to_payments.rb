class AddSourcePaymentTypeToPayments < ActiveRecord::Migration
  def change
    add_column :payments, :source_payment_type_id, :int
  end
end
