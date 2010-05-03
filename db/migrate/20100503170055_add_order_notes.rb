class AddOrderNotes < ActiveRecord::Migration
  def self.up
    add_column :orders, :notes, :text
  end

  def self.down
    add_column :orders, :notes, :text
  end
end
