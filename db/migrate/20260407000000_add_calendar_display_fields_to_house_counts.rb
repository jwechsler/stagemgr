class AddCalendarDisplayFieldsToHouseCounts < ActiveRecord::Migration[6.1]
  def change
    add_column :house_counts, :sold_out, :boolean, null: false, default: false
    add_column :house_counts, :near_capacity, :boolean, null: false, default: false
    add_column :house_counts, :min_ticket_price, :decimal, precision: 8, scale: 2
  end
end
