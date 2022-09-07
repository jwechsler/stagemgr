class AddTemporaryOrderIdToSeatAssignment < ActiveRecord::Migration[4.2]
  def change
    add_column :seat_assignments, :order_uuid, :string
    add_index :seat_assignments, :order_uuid
  end
end
