class AddDayRestrictionsToSpecialOffers < ActiveRecord::Migration
  def change
    add_column :special_offers, :day_restrictions, :integer, :default => 0
  end
end
