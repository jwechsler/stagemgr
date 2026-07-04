class AddAllocationSyncToProductions < ActiveRecord::Migration[6.1]
  def change
    add_column :productions, :allocation_sync_enqueued_at, :datetime
    add_column :productions, :allocation_sync_completed_at, :datetime
  end
end
