class AddProductionIndexes < ActiveRecord::Migration
  def self.up
    add_index :productions, :production_code

  end

  def self.down
    remove_index :productions, :production_code
  end
end
