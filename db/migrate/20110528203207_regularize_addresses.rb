class RegularizeAddresses < ActiveRecord::Migration[4.2]
  def self.up
    Address.transaction do
      Address.where('street_number is null').each do |a|
        a.last_name = 'Unknown' if a.last_name.blank?
        a.save!
      end
    end
  end

  def self.down; end
end
