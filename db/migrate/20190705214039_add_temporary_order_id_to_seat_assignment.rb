class AddTemporaryOrderIdToSeatAssignment < ActiveRecord::Migration
  def change
    add_column :seat_assignments, :order_uuid, :string
    add_index :seat_assignments, :order_uuid
  end
end
