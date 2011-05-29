class RegularizeAddresses < ActiveRecord::Migration
  def self.up
    Address.transaction do
      Address.where("street_number is null").each { |a|
        if a.last_name.blank? then
          a.last_name = 'Unknown'
        end
        a.save! }
    end

  end

  def self.down
  end
end
