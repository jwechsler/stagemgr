class SyncTicketClassAllocationsJob < ApplicationJob
  include LoggedJob

  @queue = :sync

  def self.perform(ticket_class_id)
    ticket_class = TicketClass.find_by(id: ticket_class_id)
    return if ticket_class.nil?

    production = ticket_class.production
    return if production.nil?

    performances = production.performances
                             .where("performance_date >= ?", Date.today)
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

    production.mark_allocation_sync_completed!
  rescue => e
    Rails.logger.error("SyncTicketClassAllocationsJob: Failed for ticket_class #{ticket_class_id} - #{e.message}")
    raise
  end
end
