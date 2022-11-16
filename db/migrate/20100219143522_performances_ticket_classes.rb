class PerformancesTicketClasses < ActiveRecord::Migration[4.2]
  def self.up
    create_table :performances_ticket_classes do |t|
      t.references :performance
      t.references :ticket_class
    end
  end

  def self.down
    drop_table :performances_ticket_classes
  end
end
