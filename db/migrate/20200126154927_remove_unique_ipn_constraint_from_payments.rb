class RemoveUniqueIpnConstraintFromPayments < ActiveRecord::Migration[4.2]
  def change
    remove_index :payments, column: :ipn_track_id, unique: true
    add_index :payments, :ipn_track_id
  end
end
