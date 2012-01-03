class SyncCache
  attr_accessor :addresses, :productions

  def initialize
    @addresses = Hash.new
    @productions = Hash.new
  end

  def address(address_id)
    a = @addresses[address_id]
    if a.nil?
      a = Address.find(address_id)
      @addresses[address_id] = a.sf
      a = a.sf
    end
    a
  end

  def production(production_id)
    p = @productions[production_id]
    if p.nil?
      p = Production.find(production_id)
      @productions[production_id] = p.sf
      p = p.sf
    end
    p
  end

end