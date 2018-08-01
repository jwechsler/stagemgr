class AddFullNameToAddresses < ActiveRecord::Migration
  def change
    add_column :addresses, :full_name, :string
    add_column :addresses, :middle_name, :string
  end

end
