class AddStatusToMembershipOffers < ActiveRecord::Migration[4.2]
  def change
    add_column :membership_offers, :status, :string, :default => MembershipOffer::ACTIVE
  end
end
