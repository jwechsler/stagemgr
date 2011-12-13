class AddMemberFriendCodeToMembershipOffer < ActiveRecord::Migration
  def self.up
    add_column :membership_offers, :use_member_friend_code, :string
  end

  def self.down
    remove_column :membership_offers, :use_member_friend_code
  end
end
