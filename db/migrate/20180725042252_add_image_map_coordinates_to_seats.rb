class AddImageMapCoordinatesToSeats < ActiveRecord::Migration[4.2]
  def change
    add_column :seats, :origin_x, :integer
    add_column :seats, :origin_y, :integer
    add_column :seats, :width, :integer
  end
end
