class AddSalesforceSyncToOrders < ActiveRecord::Migration
  def self.up
    add_column :orders, :sf_last_sync_at, :datetime
  end

  def self.down
    remove_column :orders, :sf_last_sync_at
  end
end
