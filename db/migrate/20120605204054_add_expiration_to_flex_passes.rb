class AddExpirationToFlexPasses < ActiveRecord::Migration
  def self.up
    add_column :flex_passes, :expiration_date, :date
    add_column :flex_passes, :active, :boolean, :default=>true
    execute "update flex_passes set expiration_date = date_add(created_at, interval 18 month)"
  end

  def self.down
    remove_column :flex_passes, :active
    remove_column :flex_passes, :expiration_date
  end
end
