class AddMembershipTypeToMembershipOffers < ActiveRecord::Migration[6.1]
  def change
    add_column :membership_offers, :membership_type, :string, default: 'production', null: false
  end
end
