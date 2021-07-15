class AddBlockFromPublicToPerformances < ActiveRecord::Migration
  def change
    add_column :performances, :withhold_from_public, :boolean, default: false
  end
end
