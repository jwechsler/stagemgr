class SyncTicketClassAllocationsJob < ApplicationJob
  include LoggedJob

  @queue = :sync

  # production_id may be nil on payloads enqueued before it was added
  # (legacy single-argument jobs); it is then derived from the ticket class.
  def self.perform(ticket_class_id, production_id = nil)
    production = Production.find_by(id: production_id) if production_id
    ticket_class = TicketClass.find_by(id: ticket_class_id)
    production ||= ticket_class&.production
    return if production.nil?

    begin
      sync_allocations(production, ticket_class) if ticket_class
    rescue StandardError => e
      Rails.logger.error("SyncTicketClassAllocationsJob: Failed for ticket_class #{ticket_class_id} - #{e.message}")
      raise
    ensure
      # Always release the pending counter, or the "allocations are updating"
      # banner stays up forever after a failed or obsolete job.
      production.mark_allocation_sync_completed!
    end
  end

  def self.sync_allocations(production, ticket_class)
    performances = production.performances
                             .where('performance_date >= ?', Date.today)
                             .where(status: Performance.sellable_statuses)

    performances.find_each do |perf|
      tca = TicketClassAllocation.find_or_initialize_by(
        performance_id: perf.id,
        ticket_class_id: ticket_class.id
      )
      if tca.new_record?
        tca.available = ticket_class.auto_attach?
      elsif ticket_class.auto_attach?
        tca.available = true
      end
      tca.save! if tca.changed? || tca.new_record?
    end
  end
end
