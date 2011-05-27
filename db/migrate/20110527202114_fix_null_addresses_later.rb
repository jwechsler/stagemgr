class FixNullAddressesLater < ActiveRecord::Migration
  def self.up
    a = Address.new(:first_name=>'Cash',:last_name=>'Sale')
    a.save!
    Order.where('address_id is null').each {|o|
      o.address = a
      o.save
    }
  end

  def self.down
  end
end
