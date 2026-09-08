class CheckPerformanceAllocationTriggers
  def self.perform
    productions = Production.where('status in (?) and (closing_at >= ? or closing_at is null)',
                                   Production.on_sale_statuses, Date.current)
    productions.each do |production|
      production.performances.each do |performance|
        performance.scan_ticket_allocation_triggers
        performance.save!
      end
    end
  end
end
