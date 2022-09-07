class AddOnSaleToMembershipOffers < ActiveRecord::Migration[4.2]
  def change
    add_column :membership_offers, :on_sale, :boolean, :default=>true
  end
end
