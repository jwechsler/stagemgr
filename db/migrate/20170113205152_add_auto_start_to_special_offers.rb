class AddAutoStartToSpecialOffers < ActiveRecord::Migration
  def change
    add_column :special_offers, :auto_start, :datetime
  end
end
