class AddShortDescriptionToProductions < ActiveRecord::Migration
  def self.up
    add_column :productions, :short_description, :string
  end

  def self.down
    remove_column :productions, :short_description
  end
end
