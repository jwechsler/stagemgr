class CreateSpecialFeatures < ActiveRecord::Migration
  has_many :performances

  def self.up
    create_table :special_features do |t|
      t.string :short_name
      t.text :description
      t.timestamps
    end
  end

  def self.down
    drop_table :special_features
  end
end
