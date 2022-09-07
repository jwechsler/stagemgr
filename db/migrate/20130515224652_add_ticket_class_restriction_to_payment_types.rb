class AddTicketClassRestrictionToPaymentTypes < ActiveRecord::Migration[4.2]
  def change
    add_column :payment_types, :restrict_to_ticket_classes, :string
  end
end
