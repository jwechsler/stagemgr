class AddHoldsSeatsToTicketClasses < ActiveRecord::Migration
  def change
    add_column :ticket_classes, :holds_seats, :boolean, :default=>true
  end
end
