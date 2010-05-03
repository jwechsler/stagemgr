class AddOrderReferralCode < ActiveRecord::Migration
  def self.up
    add_column :orders, :referral_code, :string
  end

  def self.down
    remove_column :orders, :referral_code, :string
    
  end
end
