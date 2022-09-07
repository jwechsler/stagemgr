class CreateSeatMaps < ActiveRecord::Migration[4.2]
  def change
    create_table :seat_maps do |t|
      t.string :label
      t.belongs_to :venue, index: true
      t.timestamps null: false
    end
  end
end
