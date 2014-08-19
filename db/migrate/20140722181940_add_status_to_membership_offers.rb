class AddStatusToMembershipOffers < ActiveRecord::Migration
  def change
    add_column :membership_offers, :status, :string, :default=>MembershipOffer::ACTIVE
  end
end
