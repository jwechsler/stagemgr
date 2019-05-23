class FinalizeSeasonSeating
  @queue = :maintenance

  def self.perform(production_id)
    production = Production.find(production_id)
    production.performances.each do |perf|
      perf.orders.each do |order|
        if order.held? && order.paid_with_external?
          begin
            order.transition_to!(Order::PROCESSED)
          rescue Exception => e
          end
        end
      end
    end
  end

end
