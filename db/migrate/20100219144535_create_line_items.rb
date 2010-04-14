class CreateLineItems < ActiveRecord::Migration
  def self.up
    create_table :line_items do |t|
      t.references :ticket_class
      t.references :order
      t.integer :ticket_count
      t.float :price_override

      t.timestamps
    end
  end

  def self.down
    drop_table :line_items
  end
end
