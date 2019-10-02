class AddTicketInfoToSeatAssignment < ActiveRecord::Migration
  def change
    add_column :seat_assignments, :ticket_class_id, :int
  end
end
