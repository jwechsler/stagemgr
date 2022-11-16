class AddUniqueExpirationsToSpecialOffers < ActiveRecord::Migration[4.2]
  def self.up
    add_column :special_offers, :number_of_uses, :integer
    add_column :special_offers, :auto_expire, :date
    add_column :special_offers, :status, :string, :default=>'Active'
  end

  def self.down
    remove_column :special_offers, :auto_expire
    remove_column :special_offers, :number_of_uses
    remove_column :special_offers, :status
  end
end
