class AddExpirationToFlexPasses < ActiveRecord::Migration[4.2]
  def self.up
    add_column :flex_passes, :expiration_date, :date
    add_column :flex_passes, :active, :boolean, :default => true
  end

  def self.down
    remove_column :flex_passes, :active
    remove_column :flex_passes, :expiration_date
  end
end
