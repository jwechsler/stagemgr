class AddFieldsToLineItems < ActiveRecord::Migration
  def self.up
    add_column :line_items, :ticket_count, :integer
    add_column :line_items, :price_override, :float
  end

  def self.down
    remove_column :line_items, :ticket_count
    remove_column :line_items, :price_override
  end
end
