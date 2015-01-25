class AddAssignsSeatsToDefaultTicketClasses < ActiveRecord::Migration
  def change
    add_column :default_ticket_classes, :assigns_seats, :boolean, :default=>false
  end
end
