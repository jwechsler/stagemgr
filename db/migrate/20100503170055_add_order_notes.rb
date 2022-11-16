class AddOrderNotes < ActiveRecord::Migration[4.2]
  def self.up
    add_column :orders, :notes, :text
  end

  def self.down
    remove_column :orders, :notes, :text
  end
end
