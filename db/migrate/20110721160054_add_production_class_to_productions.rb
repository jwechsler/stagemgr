class AddProductionClassToProductions < ActiveRecord::Migration
  def self.up
    add_column :productions, :production_class, :string, :default=>Production::PLAY
  end

  def self.down
    remove_column :productions, :production_class
  end
end
