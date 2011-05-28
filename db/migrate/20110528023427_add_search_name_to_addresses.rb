class AddSearchNameToAddresses < ActiveRecord::Migration
  def self.up
    add_column :addresses, :search_name, :string
  end

  def self.down
    remove_column :addresses, :search_name
  end
end
