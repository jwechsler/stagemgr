class AddSoftwareManagedToDefaultTicketClasses < ActiveRecord::Migration[4.2]
  def self.up
    add_column :default_ticket_classes, :software_managed, :boolean
    add_column :ticket_classes, :software_managed, :boolean
  end

  def self.down
    remove_column(:ticket_classes, :software_managed)
    remove_column :default_ticket_classes, :software_managed
  end
end
