class AddTicketClassToSpecialOffer < ActiveRecord::Migration[4.2]
  def self.up
    add_column :special_offers, :system_generated, :boolean, default: false
    add_column :special_offers, :change_ticket_class_code, :string
    add_column :special_offers, :max_tickets_per_order, :integer, default: false
    execute "update special_offers set system_generated = 1 where code like '1T%'"
  end

  def self.down
    remove_column :special_offers, :max_tickets_per_order
    remove_column :special_offers, :change_ticket_class_code
    remove_column :special_offers, :system_generated
  end
end
