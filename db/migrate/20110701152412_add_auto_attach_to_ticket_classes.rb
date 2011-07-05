class AddAutoAttachToTicketClasses < ActiveRecord::Migration
  def self.up
    add_column :ticket_classes, :auto_attach, :boolean
    add_column :default_ticket_classes, :auto_attach, :boolean
  end

  def self.down
    remove_column :default_ticket_classes, :auto_attach
    remove_column :ticket_classes, :auto_attach
  end
end
