class AddHoldsSeatsToDefaultTicketClass < ActiveRecord::Migration[4.2]
  def change
    add_column :default_ticket_classes, :holds_seats, :boolean, :default => true
  end
end
