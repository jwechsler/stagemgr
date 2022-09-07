class AddReservesSeatsToTicketClass < ActiveRecord::Migration[4.2]
  def change
    add_column :ticket_classes, :assigns_seats, :boolean, :default=>false
  end
end
