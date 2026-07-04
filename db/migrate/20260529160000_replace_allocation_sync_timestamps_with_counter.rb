class ReplaceAllocationSyncTimestampsWithCounter < ActiveRecord::Migration[6.1]
  def up
    remove_column :productions, :allocation_sync_enqueued_at
    remove_column :productions, :allocation_sync_completed_at
    add_column :productions, :allocation_sync_pending_count, :integer, default: 0, null: false
  end

  def down
    remove_column :productions, :allocation_sync_pending_count
    add_column :productions, :allocation_sync_enqueued_at, :datetime
    add_column :productions, :allocation_sync_completed_at, :datetime
  end
end
