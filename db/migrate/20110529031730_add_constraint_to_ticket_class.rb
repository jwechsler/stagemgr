class AddConstraintToTicketClass < ActiveRecord::Migration
  def change
    add_foreign_key :line_items, :ticket_classes
  end

end
