class FixAmountOfferDefault < ActiveRecord::Migration
  def self.up
    change_column :special_offers, :amount, :float, :default=>0.0
  end

  def self.down
    change_column :special_offers, :amount, :float, :default=>nil
  end
end
