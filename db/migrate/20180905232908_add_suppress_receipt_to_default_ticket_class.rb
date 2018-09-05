class AddSuppressReceiptToDefaultTicketClass < ActiveRecord::Migration
  def change
    add_column :default_ticket_classes, :suppress_receipt, :boolean
  end
end
