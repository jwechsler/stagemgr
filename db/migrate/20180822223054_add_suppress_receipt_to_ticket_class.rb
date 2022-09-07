class AddSuppressReceiptToTicketClass < ActiveRecord::Migration[4.2]
  def change
    add_column :ticket_classes, :suppress_receipt, :boolean, default: false
  end
end
