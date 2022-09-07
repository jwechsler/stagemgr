class CreateTicketClassAllocations < ActiveRecord::Migration[4.2]
  def self.up
    create_table :ticket_class_allocations do |t|
      t.references :performance
      t.references :ticket_class
      t.boolean :available
      t.integer :ticket_limit

      t.timestamps
    end
  end

  def self.down
    drop_table :ticket_class_allocations
  end
end
