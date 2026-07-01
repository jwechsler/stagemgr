class AddOrderReferralCode < ActiveRecord::Migration[4.2]
  def self.up
    add_column :orders, :referral_code, :string
  end

  def self.down
    remove_column :orders, :referral_code, :string
  end
end
