class AddFlatPayoutToFlexPassOffers < ActiveRecord::Migration
  def self.up
    add_column :flex_pass_offers, :flat_payout, :decimal
  end

  def self.down
    remove_column :flex_pass_offers, :flat_payout
  end
end
