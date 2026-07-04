class AddDayRestrictionsToSpecialOffers < ActiveRecord::Migration[4.2]
  def change
    add_column :special_offers, :day_restrictions, :integer, default: 0
  end
end
