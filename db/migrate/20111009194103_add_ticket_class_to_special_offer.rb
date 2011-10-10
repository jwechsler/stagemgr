class AddTicketClassToSpecialOffer < ActiveRecord::Migration
  def self.up
    add_column :special_offers, :ticket_class_id, :integer
    add_column :special_offers, :max_tickets_per_order, :boolean, :default=>false
  end

  def self.down
    remove_column :special_offers, :max_tickets_per_order
    remove_column :special_offers, :ticket_class_id
  end
end
