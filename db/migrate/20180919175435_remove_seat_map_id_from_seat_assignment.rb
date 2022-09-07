class RemoveSeatMapIdFromSeatAssignment < ActiveRecord::Migration[4.2]
  def change
    remove_column :seat_assignments, :seat_map_id
  end
end
