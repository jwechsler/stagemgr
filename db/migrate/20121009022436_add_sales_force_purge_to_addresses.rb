class AddSalesForcePurgeToAddresses < ActiveRecord::Migration
  def change
    add_column :addresses, :sf_purge, :integer
  end
end
