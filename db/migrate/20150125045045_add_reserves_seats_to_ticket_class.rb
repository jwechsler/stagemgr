class AddReservesSeatsToTicketClass < ActiveRecord::Migration
  def change
    add_column :ticket_classes, :assigns_seats, :boolean, :default=>false
  end
end
