class RenameTicketClassCodeForMembershipOffers < ActiveRecord::Migration
  def self.up
    rename_column :membership_offers, :ticket_class_code, :use_ticket_class_code
  end

  def self.down
    rename_column :membership_offers, :use_ticket_class_code, :ticket_class_code
  end
end
