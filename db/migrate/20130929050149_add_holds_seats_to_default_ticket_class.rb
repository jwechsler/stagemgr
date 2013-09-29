class AddHoldsSeatsToDefaultTicketClass < ActiveRecord::Migration
  def change
    add_column :default_ticket_classes, :holds_seats, :boolean, :default=>true
  end
end
