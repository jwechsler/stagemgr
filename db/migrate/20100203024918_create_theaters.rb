class CreateTheaters < ActiveRecord::Migration
  def self.up
    create_table :theaters do |t|
      t.string :name
      t.string :url
      t.binary :logo
      t.string :theater_class
      t.string :status

      t.timestamps
    end
  end

  def self.down
    drop_table :theaters
  end
end
