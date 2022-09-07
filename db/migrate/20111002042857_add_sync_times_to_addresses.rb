class AddSyncTimesToAddresses < ActiveRecord::Migration[4.2]
  def self.up
    add_column :addresses, :sf_last_sync_at, :datetime
  end

  def self.down
    remove_column :addresses, :sf_last_sync_at
  end
end
