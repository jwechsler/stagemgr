class AddHtmlDescriptionToMembershipOffers < ActiveRecord::Migration
  def self.up
    add_column :membership_offers, :html_description, :text
  end

  def self.down
    remove_column :membership_offers, :html_description
  end
end
