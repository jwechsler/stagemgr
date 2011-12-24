class AddSalesforceSyncDateToProductions < ActiveRecord::Migration
  def self.up
    add_column :productions, :sf_last_sync_at, :datetime
  end

  def self.down
    remove_column :productions, :sf_last_sync_at
  end
end
