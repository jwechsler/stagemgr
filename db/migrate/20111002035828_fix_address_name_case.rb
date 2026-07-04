class FixAddressNameCase < ActiveRecord::Migration[4.2]
  def self.up
    Address.all.each do |address|
      address.first_name = NameCase(address.first_name)
      address.last_name = NameCase(address.last_name)
      address.save! if address.first_name_changed? || address.last_name_changed?
    end
  end

  def self.down; end
end
