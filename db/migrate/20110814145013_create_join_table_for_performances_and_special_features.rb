class CreateJoinTableForPerformancesAndSpecialFeatures < ActiveRecord::Migration
  def self.up
    remove_column :performances, :special_feature_id
    remove_column :performances, :footnote
    create_table :performances_special_features, :id=>false do |t|
      t.integer :performance_id
      t.integer :special_feature_id
    end
  end

  def self.down
    drop_table :performances_special_features
    add_column :performances, :special_feature_id, :integer
    add_column :performances, :footnote, :string
  end
end
