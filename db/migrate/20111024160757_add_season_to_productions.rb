class AddSeasonToProductions < ActiveRecord::Migration[4.2]
  def self.up
    add_column :productions, :season, :integer

  end

  def self.down
    remove_column :productions, :season
  end
end
