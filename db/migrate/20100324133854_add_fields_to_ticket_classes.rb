class AddFieldsToTicketClasses < ActiveRecord::Migration
  def self.up
    add_column :ticket_classes, :description, :string
  end

  def self.down
    remove_column :ticket_classes, :description
  end
end
