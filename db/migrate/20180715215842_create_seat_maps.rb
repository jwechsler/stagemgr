class CreateSeatMaps < ActiveRecord::Migration
  def change
    create_table :seat_maps do |t|
      t.string :label
      t.belongs_to :venue, index: true
      t.timestamps null: false
    end
  end
end
