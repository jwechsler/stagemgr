class CreateTicketClasses < ActiveRecord::Migration
  def self.up
    create_table :ticket_classes do |t|
      t.string :class_code
      t.float :price

      t.timestamps
    end
  end

  def self.down
    drop_table :ticket_classes
  end
end
