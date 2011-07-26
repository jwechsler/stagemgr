class AddOrdinalToVenues < ActiveRecord::Migration
  def self.up
    add_column :venues, :ordinal_sort, :string
  end

  def self.down
    remove_column :venues, :ordinal_sort
  end
end
