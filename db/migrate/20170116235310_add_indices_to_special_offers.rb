class AddIndicesToSpecialOffers < ActiveRecord::Migration[4.2]
  def change
    add_index :special_offers, :production_id
    add_index :special_offers, :performance_id
    add_index :special_offers, :theater_id
    add_index :special_offers, :code
    add_index :special_offers, :system_generated
  end
end
