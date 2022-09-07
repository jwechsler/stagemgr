class AddVenueToProductions < ActiveRecord::Migration[4.2]
  def self.up
    add_column :productions, :venue_id, :integer
  end

  def self.down
    remove_column :productions, :venue_id
  end
end
