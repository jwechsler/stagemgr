class GenerateProductionSalesStatistics
  @queue = :maintenance

  def self.perform(production_id = nil)
    if production_id.nil?
      @productions = Production.where('status in (?) or id not in (select production_id from production_stats)',
                                      Production.on_sale_statuses)
    else
      @productions = [Production.find(production_id)]
    end
    @productions.each { |prod|
      stats = prod.update_stats
      stats.build_pending_snapshots
    }
  end
end
