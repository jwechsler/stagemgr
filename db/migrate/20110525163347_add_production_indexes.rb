class AddProductionIndexes < ActiveRecord::Migration[4.2]
  def self.up
    add_index :productions, :production_code
  end

  def self.down
    remove_index :productions, :production_code
  end
end
