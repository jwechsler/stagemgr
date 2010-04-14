class CreateTheaters < ActiveRecord::Migration
  def self.up
    create_table :theaters do |t|
      t.string :name
      t.string :url
      t.string :theater_class
      t.string :status
      t.string :logo_file_name
      t.string :logo_content_type
      t.integer :logo_file_size
      t.datetime :logo_updated_at

      t.timestamps
    end
  end

  def self.down
    drop_table :theaters
  end
end
