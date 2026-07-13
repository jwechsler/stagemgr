# Indexes for the status/type/date predicates used by the terminal-state order
# scopes, date-ranged payment reports, OrderTask.run_pending (every 5 minutes),
# address email search, and the maintenance jobs added by the data-retention
# work. Also drops payments_oid_i, an exact duplicate of
# index_payments_on_order_id. See docs/data-retention-strategy.md.
class AddRetentionAndReportingIndexes < ActiveRecord::Migration[6.1]
  def change
    add_index :orders, :status
    add_index :orders, [:type, :status]

    add_index :payments, :processed_on
    remove_index :payments, column: :order_id, name: 'payments_oid_i'

    add_index :order_tasks, [:status, :execute_at]

    add_index :addresses, :email
    add_index :addresses, :updated_at

    add_index :job_metadata, :job_name
  end
end
