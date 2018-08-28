class AddSuppressReceiptToTicketClass < ActiveRecord::Migration
  def change
    add_column :ticket_classes, :suppress_receipt, :boolean, default: false
  end
end
