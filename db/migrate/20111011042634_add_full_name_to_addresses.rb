class AddFullNameToAddresses < ActiveRecord::Migration
  def self.up
    add_column :addresses, :full_name, :string
    add_column :addresses, :middle_name, :string
    execute "update addresses set full_name = trim(concat(ifnull(first_name,''),' ',ifnull(last_name,'')))"
  end

  def self.down
    remove_column :addresses, :middle_name
    remove_column :addresses, :full_name
  end
end
