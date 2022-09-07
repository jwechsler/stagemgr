class CreateVenues < ActiveRecord::Migration[4.2]
  def self.up
    create_table :venues do |t|
      t.string :name
      t.timestamps
    end
  end

  def self.down
    drop_table :venues
  end
end
