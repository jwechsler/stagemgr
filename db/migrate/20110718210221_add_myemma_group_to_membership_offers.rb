class AddMyemmaGroupToMembershipOffers < ActiveRecord::Migration[4.2]
  def self.up
    add_column :membership_offers, :myemma_group, :string
  end

  def self.down
    remove_column :membership_offers, :myemma_group
  end
end
