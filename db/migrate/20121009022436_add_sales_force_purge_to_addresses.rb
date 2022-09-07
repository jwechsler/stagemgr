class AddSalesForcePurgeToAddresses < ActiveRecord::Migration[4.2]
  def change
    add_column :addresses, :sf_purge, :integer
  end
end
