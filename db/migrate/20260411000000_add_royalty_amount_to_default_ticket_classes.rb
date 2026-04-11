class AddRoyaltyAmountToDefaultTicketClasses < ActiveRecord::Migration[6.1]
  def change
    add_column :default_ticket_classes, :royalty_amount, :decimal, precision: 8, scale: 2, null: true
  end
end
