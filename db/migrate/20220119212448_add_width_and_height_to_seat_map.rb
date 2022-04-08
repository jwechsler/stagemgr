class AddWidthAndHeightToSeatMap < ActiveRecord::Migration
  def change
    add_column :seat_maps, :original_width, :integer
    add_column :seat_maps, :original_height, :integer
  end
end
