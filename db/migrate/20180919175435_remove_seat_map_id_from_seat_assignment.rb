class RemoveSeatMapIdFromSeatAssignment < ActiveRecord::Migration
  def change
    remove_column :seat_assignments, :seat_map_id
  end
end
