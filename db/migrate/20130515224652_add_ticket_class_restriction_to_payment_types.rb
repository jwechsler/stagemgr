class AddTicketClassRestrictionToPaymentTypes < ActiveRecord::Migration
  def change
    add_column :payment_types, :restrict_to_ticket_classes, :string
  end
end
