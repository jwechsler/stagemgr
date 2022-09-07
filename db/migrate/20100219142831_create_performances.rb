class CreatePerformances < ActiveRecord::Migration[4.2]
  def self.up
    create_table :performances do |t|
      t.references :production
      t.date :performance_date
      t.time :performance_time
      t.string :status
      t.string :performance_code

      t.timestamps
    end
  end

  def self.down
    drop_table :performances
  end
end
