class AddPrefixToAddresses < ActiveRecord::Migration[4.2]
  def change
    add_column :addresses, :prefix, :string
  end
end
