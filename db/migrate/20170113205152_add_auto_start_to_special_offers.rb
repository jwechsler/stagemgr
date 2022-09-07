class AddAutoStartToSpecialOffers < ActiveRecord::Migration[4.2]
  def change
    add_column :special_offers, :auto_start, :datetime
  end
end
