class AddProductionClassToProductions < ActiveRecord::Migration[4.2]
  def self.up
    add_column :productions, :production_class, :string, :default=>Production::PLAY
  end

  def self.down
    remove_column :productions, :production_class
  end
end
