class AddParsedAddressIndexes < ActiveRecord::Migration
  def self.up
    add_index :addresses, [:search_name, :email]
    add_index :addresses, [:street_number, :street, :city, :search_name], :name=>'index_address_search'
  end

  def self.down
  end
end
