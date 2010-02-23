class CreateLineItems < ActiveRecord::Migration
  def self.up
    create_table :line_items do |t|
      t.references :performance
      t.references :ticket_class
      t.references :order

      t.timestamps
    end
  end

  def self.down
    drop_table :line_items
  end
end
