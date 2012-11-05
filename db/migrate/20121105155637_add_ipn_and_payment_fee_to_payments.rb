class AddIpnAndPaymentFeeToPayments < ActiveRecord::Migration
  def change
    add_column :payments, :ipn_track_id, :string
    add_column :payments, :payment_fee, :float
  end
end
