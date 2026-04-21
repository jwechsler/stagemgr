class AddSeatAssignmentIdToLineItems < ActiveRecord::Migration[6.1]
  def change
    add_column :line_items, :seat_assignment_id, :integer, null: true
    # MySQL unique indexes permit multiple NULLs; this enforces the 1:1
    # pairing only for reserved-seating TLIs that populate the column.
    add_index :line_items, :seat_assignment_id, unique: true, name: 'index_line_items_on_seat_assignment_id'
  end
end
