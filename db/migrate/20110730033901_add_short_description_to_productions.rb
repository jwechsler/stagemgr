class AddShortDescriptionToProductions < ActiveRecord::Migration[4.2]
  def self.up
    add_column :productions, :short_description, :string
  end

  def self.down
    remove_column :productions, :short_description
  end
end
