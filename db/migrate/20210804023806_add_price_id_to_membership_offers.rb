class AddPriceIdToMembershipOffers < ActiveRecord::Migration
  def change
    add_column :membership_offers, :price_id, :string
  end
end
