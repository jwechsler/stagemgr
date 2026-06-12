class CheckPerformanceAllocationTriggers
  def self.perform
    productions = Production.where('status in (?) and (closing_at >= ? or closing_at is null)',
                                   Production.on_sale_statuses, Date.today)
    productions.each { |production|
      production.performances.each { |performance|
        performance.scan_ticket_allocation_triggers
        performance.save!
      }
    }
  end
end
