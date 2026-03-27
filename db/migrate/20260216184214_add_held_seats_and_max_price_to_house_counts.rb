class AddHeldSeatsAndMaxPriceToHouseCounts < ActiveRecord::Migration[6.1]
  def change
    add_column :house_counts, :held_seats, :integer, null: false, default: 0
    add_column :house_counts, :max_ticket_price, :decimal, precision: 8, scale: 2
  end
end
