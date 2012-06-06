class AddExpirationToFlexPassOffers < ActiveRecord::Migration
  def self.up
    add_column :flex_pass_offers, :months_till_expiration, :integer, :default=>18
  end

  def self.down
    remove_column :flex_pass_offers, :months_till_expiration
  end
end
