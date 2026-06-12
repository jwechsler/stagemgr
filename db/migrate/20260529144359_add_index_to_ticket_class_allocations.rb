class AddIndexToTicketClassAllocations < ActiveRecord::Migration[6.1]
  def change
    add_index :ticket_class_allocations, [:performance_id, :ticket_class_id],
              name: 'index_tca_on_performance_and_ticket_class'
  end
end
