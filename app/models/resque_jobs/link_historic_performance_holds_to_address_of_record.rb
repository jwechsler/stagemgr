class LinkHistoricPerformanceHoldsToAddressOfRecord

  @queue = :maintenance

  def self.perform
    begin
      orders = Order.joins(:performance).where(
        "orders.status = 'Hold' and performances.performance_date < ?", Date.today - 1.day)
      orders.each do |o|
        o.link_to_address_of_record
        o.save!
      end
    end
  end

end
