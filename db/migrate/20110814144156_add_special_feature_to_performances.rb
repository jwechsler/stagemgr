class AddSpecialFeatureToPerformances < ActiveRecord::Migration
  def self.up
    add_column :performances, :special_feature_id, :integer
  end

  def self.down
    remove_column :performances, :special_feature_id
  end
end
