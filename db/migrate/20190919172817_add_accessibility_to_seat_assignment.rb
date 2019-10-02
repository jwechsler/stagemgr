class AddAccessibilityToSeatAssignment < ActiveRecord::Migration
  def change
    add_column :seat_assignments, :accessibility, :string
  end
end
