class GenerateProductionSalesStatistics
  @queue = :maintenance

  def self.perform(production_id = nil)
    @productions = if production_id.nil?
                     Production.where('status in (?) or id not in (select production_id from production_stats)',
                                      Production.on_sale_statuses)
                   else
                     [Production.find(production_id)]
                   end
    @productions.each do |prod|
      stats = prod.update_stats
      stats.build_pending_snapshots
    end
  end
end
