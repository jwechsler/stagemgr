class AddAssignsSeatsToDefaultTicketClasses < ActiveRecord::Migration[4.2]
  def change
    add_column :default_ticket_classes, :assigns_seats, :boolean, default: false
  end
end
