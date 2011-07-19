class AddAddressIdToLineItems < ActiveRecord::Migration
  def self.up
    add_column :line_items, :address_id, :integer
  end

  def self.down
    remove_column :line_items, :address_id
  end
end
