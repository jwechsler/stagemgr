class AddAccessibilityToSeatAssignment < ActiveRecord::Migration[4.2]
  def change
    add_column :seat_assignments, :accessibility, :string
  end
end
