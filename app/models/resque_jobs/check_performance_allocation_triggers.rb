class CheckPerformanceAllocationTriggers

  def self.perform
    Authorization.ignore_access_control(true)
    begin
      productions = Production.where('status in (?) and (closing_at >= ? or closing_at is null)', Production.on_sale_statuses, Date.today)
      productions.each { |production|
        production.performances.each { |performance| performance.scan_ticket_allocation_triggers
          performance.save! }
      }
    ensure
      Authorization.ignore_access_control(false)
    end
  end

end
