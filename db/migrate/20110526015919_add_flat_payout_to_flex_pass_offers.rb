class AddFlatPayoutToFlexPassOffers < ActiveRecord::Migration[4.2]
  def self.up
    add_column :flex_pass_offers, :flat_payout, :decimal
  end

  def self.down
    remove_column :flex_pass_offers, :flat_payout
  end
end
