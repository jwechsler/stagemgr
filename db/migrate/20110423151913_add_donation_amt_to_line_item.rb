class AddDonationAmtToLineItem < ActiveRecord::Migration
  def self.up
    add_column :line_items, :donation_amount, :float
  end

  def self.down
    remove_column :line_items, :donation_amount
  end
end
