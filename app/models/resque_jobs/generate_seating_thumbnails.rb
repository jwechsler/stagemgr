class GenerateSeatingThumbnails

  def self.perform
    prod_ids_with_seating = Production.where.not(seat_map_id: nil).where(status: Production.on_sale_statuses).pluck(:id)
    perfs_with_seating = Performance.where(production_id: prod_ids_with_seating, status: Performance.sellable_statuses)
    perfs_with_seating.each { |perf| perf.generate_seating_thumbnail }
    nil
  end

end
