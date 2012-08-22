class AddOnSaleToMembershipOffers < ActiveRecord::Migration
  def change
    add_column :membership_offers, :on_sale, :boolean, :default=>true
  end
end
