class AddUseTicketClassCodeToFlexPassOffers < ActiveRecord::Migration
  def self.up
    add_column :flex_pass_offers, :use_ticket_class_code, :string
  end

  def self.down
    remove_column :flex_pass_offers, :use_ticket_class_code
  end
end
