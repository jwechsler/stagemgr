class AddImageMapCoordinatesToSeats < ActiveRecord::Migration
  def change
    add_column :seats, :origin_x, :integer
    add_column :seats, :origin_y, :integer
    add_column :seats, :width, :integer
  end
end
