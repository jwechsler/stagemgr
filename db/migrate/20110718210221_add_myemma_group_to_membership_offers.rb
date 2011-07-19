class AddMyemmaGroupToMembershipOffers < ActiveRecord::Migration
  def self.up
    add_column :membership_offers, :myemma_group, :string
  end

  def self.down
    remove_column :membership_offers, :myemma_group
  end
end
