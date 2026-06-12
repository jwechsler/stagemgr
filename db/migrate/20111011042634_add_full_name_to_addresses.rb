class AddFullNameToAddresses < ActiveRecord::Migration[4.2]
  def change
    add_column :addresses, :full_name, :string
    add_column :addresses, :middle_name, :string
  end
end
