class CreateSeats < ActiveRecord::Migration[4.2]
  def change
    create_table :seats do |t|
      t.string :location, null: false
      t.string :zone
      t.string :row, null: false
      t.integer :seat_number, null: false
      t.belongs_to :seat_map, index: true
      t.timestamps null: false
    end
  end
end
