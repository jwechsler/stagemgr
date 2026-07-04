class InactivateOlderProductions
  @queue = :maintenance

  def self.perform
    prods = Production.where('status = :active and closing_at < :closing', active: Production::ACTIVE,
                                                                           closing: Date.today - 24.months)
    prods.each do |p|
      p.status = Production::INACTIVE
      p.save!
    end
  end
end
