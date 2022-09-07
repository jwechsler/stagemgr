class AddSearchNameToAddresses < ActiveRecord::Migration[4.2]
  def self.up
    add_column :addresses, :search_name, :string
  end

  def self.down
    remove_column :addresses, :search_name
  end
end
