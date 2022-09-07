class AddSpecialFeatureToPerformances < ActiveRecord::Migration[4.2]
  def self.up
    add_column :performances, :special_feature_id, :integer
  end

  def self.down
    remove_column :performances, :special_feature_id
  end
end
