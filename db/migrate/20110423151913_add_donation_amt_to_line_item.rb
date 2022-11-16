class AddDonationAmtToLineItem < ActiveRecord::Migration[4.2]
  def self.up
    add_column :line_items, :donation_amount, :float
  end

  def self.down
    remove_column :line_items, :donation_amount
  end
end
