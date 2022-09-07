class AddTicketClassCodeToSpecialOffer < ActiveRecord::Migration[4.2]
  def self.up
    add_column :special_offers, :ticket_class_code, :string
    remove_column :special_offers, :ticket_class_id
  end

  def self.down
    add_column :special_offers, :ticket_class_id, :integer
    remove_column :special_offers, :ticket_class_code
  end
end
