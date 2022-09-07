class AddOrdinalToVenues < ActiveRecord::Migration[4.2]
  def self.up
    add_column :venues, :ordinal_sort, :string
  end

  def self.down
    remove_column :venues, :ordinal_sort
  end
end
