class AddSalesforceSyncToOrders < ActiveRecord::Migration[4.2]
  def self.up
    add_column :orders, :sf_last_sync_at, :datetime
  end

  def self.down
    remove_column :orders, :sf_last_sync_at
  end
end
