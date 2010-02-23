class PerformancesTicketClasses < ActiveRecord::Migration
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
