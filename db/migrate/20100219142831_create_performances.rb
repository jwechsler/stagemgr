class CreatePerformances < ActiveRecord::Migration
  def self.up
    create_table :performances do |t|
      t.date :on
      t.datetime :at
      t.references :production

      t.timestamps
    end
  end

  def self.down
    drop_table :performances
  end
end
