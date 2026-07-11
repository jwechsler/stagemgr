class AddBxgyQuantitiesToSpecialOffers < ActiveRecord::Migration[6.1]
  def change
    add_column :special_offers, :buy_quantity, :integer
    add_column :special_offers, :get_quantity, :integer
  end
end
