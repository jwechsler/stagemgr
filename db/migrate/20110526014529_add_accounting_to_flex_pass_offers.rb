class AddAccountingToFlexPassOffers < ActiveRecord::Migration
  def self.up
    add_column :flex_pass_offers, :facility_fee, :decimal
    add_column :flex_pass_offers, :spiff, :decimal
  end

  def self.down
    remove_column :flex_pass_offers, :spiff
    remove_column :flex_pass_offers, :facility_fee
  end
end
