class MigrateSeatMapToActiveStorage < ActiveRecord::Migration[5.2]
  def change
    SeatMap.all.each { |map| map.base_image_map.analyze }
    remove_column :seat_maps, :original_width, :integer
    remove_column :seat_maps, :original_height, :integer
  end
end
