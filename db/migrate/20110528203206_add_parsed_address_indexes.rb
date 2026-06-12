class AddParsedAddressIndexes < ActiveRecord::Migration[4.2]
  def self.up
    add_index :addresses, [:search_name, :email]
    add_index :addresses, [:street_number, :street], :name => 'index_address_search'
  end

  def self.down
  end
end
