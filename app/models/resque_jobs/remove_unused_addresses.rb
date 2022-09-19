class RemoveUnusedAddresses
  @queue = :maintenance

  def self.perform
    addresses = Address.includes(:address_tags).where("id not in (select address_id from orders) and updated_at < (CURRENT_DATE - INTERVAL 1 DAY)")
    addresses.select {|address| 
      address.address_tags.size.eql?(0) && address.productions_attended.size.eql?(0)
    }.each { |address|
      address.destroy 
    }
  end
 end
