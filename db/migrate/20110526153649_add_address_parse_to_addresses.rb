class AddAddressParseToAddresses < ActiveRecord::Migration[4.2]
  def self.up
    add_column :addresses, :street_number, :string
    add_column :addresses, :street, :string
    add_column :addresses, :street_type, :string
    add_column :addresses, :unit, :string
    add_column :addresses, :unit_prefix, :string
  end

  def self.down
    remove_column :addresses, :unit_prefix
    remove_column :addresses, :unit
    remove_column :addresses, :street_type
    remove_column :addresses, :street
    remove_column :addresses, :street_number
  end
end
