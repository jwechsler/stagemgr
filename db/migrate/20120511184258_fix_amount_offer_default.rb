class FixAmountOfferDefault < ActiveRecord::Migration[4.2]
  def self.up
    change_column :special_offers, :amount, :float, :default => 0.0
  end

  def self.down
    change_column :special_offers, :amount, :float, :default => nil
  end
end
