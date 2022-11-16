class AddSuppressReceiptToDefaultTicketClass < ActiveRecord::Migration[4.2]
  def change
    add_column :default_ticket_classes, :suppress_receipt, :boolean
  end
end
