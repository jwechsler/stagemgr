class AddSeasonToProductions < ActiveRecord::Migration
  def self.up
    add_column :productions, :season, :integer

  end

  def self.down
    remove_column :productions, :season
  end
end
