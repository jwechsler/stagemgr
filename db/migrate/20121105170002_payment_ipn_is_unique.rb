class PaymentIpnIsUnique < ActiveRecord::Migration
  def up
    add_index :payments, :ipn_track_id, :unique=>true
  end

  def down
    drop_index :payments, :ipn_track_id
  end
end
