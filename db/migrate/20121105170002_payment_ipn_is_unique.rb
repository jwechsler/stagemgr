class PaymentIpnIsUnique < ActiveRecord::Migration[4.2]
  def up
    add_index :payments, :ipn_track_id, unique: true
  end

  def down
    drop_index :payments, :ipn_track_id
  end
end
