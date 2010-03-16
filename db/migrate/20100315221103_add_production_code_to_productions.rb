class AddProductionCodeToProductions < ActiveRecord::Migration
  def self.up
    add_column :productions, :production_code, :string
  end

  def self.down
    remove_column :productions, :production_code
  end
end
