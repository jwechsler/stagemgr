class AddPaypalFieldsToMemberships < ActiveRecord::Migration
  def self.up
    add_column :memberships, :profile_id, :string
    add_column :membership_offers, :billing_agreement, :text
  end

  def self.down
    remove_column :memberships, :profile_id
    remove_column :membership_offers, :billing_agreement
  end
end
