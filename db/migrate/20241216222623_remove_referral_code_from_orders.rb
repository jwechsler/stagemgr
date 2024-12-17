class RemoveReferralCodeFromOrders < ActiveRecord::Migration[6.1]
  def up
    remove_column :orders, :referral_code, :string
  end

  def down
    add_column :orders, :referral_code, :string
  end
end
