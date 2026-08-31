class AddResourcedTicketClassIdToTicketClasses < ActiveRecord::Migration[6.1]
  # Nullable FK marking a ticket class as a "shadow" row owned by a
  # ResourcedTicketClass. Shadow rows are attribute-synced from the resource and
  # are read-only in the per-production admin.
  def change
    add_column :ticket_classes, :resourced_ticket_class_id, :integer
    add_index  :ticket_classes, :resourced_ticket_class_id
  end
end
