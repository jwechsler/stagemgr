class AddConstraintToTicketClass < ActiveRecord::Migration[4.2]
  def change
    add_foreign_key :line_items, :ticket_classes
  end

end
