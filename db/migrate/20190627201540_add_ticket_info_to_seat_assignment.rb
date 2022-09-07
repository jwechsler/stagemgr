class AddTicketInfoToSeatAssignment < ActiveRecord::Migration[4.2]
  def change
    add_column :seat_assignments, :ticket_class_id, :int
  end
end
