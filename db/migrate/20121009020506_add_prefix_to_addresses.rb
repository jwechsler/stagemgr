class AddPrefixToAddresses < ActiveRecord::Migration
  def change
    add_column :addresses, :prefix, :string
  end
end
