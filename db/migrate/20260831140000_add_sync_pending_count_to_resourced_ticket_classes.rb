class AddSyncPendingCountToResourcedTicketClasses < ActiveRecord::Migration[6.1]
  # Mirrors productions.allocation_sync_pending_count: a counter of in-flight
  # SyncResourcedTicketClassJob runs, so the admin show page can display a
  # "syncing" banner instead of misreporting not-yet-synced productions as
  # class_code collisions while the job is still queued.
  def change
    add_column :resourced_ticket_classes, :sync_pending_count, :integer, null: false, default: 0
  end
end
