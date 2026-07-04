class AddStatusToSpecialFeature < ActiveRecord::Migration[4.2]
  def self.up
    add_column :special_features, :status, :string, default: 'Active'
  end

  def self.down
    remove_column :special_features, :status
  end
end
