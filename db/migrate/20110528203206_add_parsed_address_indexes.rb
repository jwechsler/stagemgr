class AddParsedAddressIndexes < ActiveRecord::Migration[4.2]
  def self.up
    add_index :addresses, %i[search_name email]
    add_index :addresses, %i[street_number street], name: 'index_address_search'
  end

  def self.down; end
end
