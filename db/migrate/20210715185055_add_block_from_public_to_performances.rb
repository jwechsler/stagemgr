class AddBlockFromPublicToPerformances < ActiveRecord::Migration[4.2]
  def change
    add_column :performances, :withhold_from_public, :boolean, default: false
  end
end
