class InactivateUnusedProductions
  @queue = :maintenance

  def self.perform
    Production.inactivate_unused
  end

end
