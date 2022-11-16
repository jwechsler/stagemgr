class AddPriceIdToMembershipOffers < ActiveRecord::Migration[4.2]
  def change
    add_column :membership_offers, :price_id, :string
  end
end
