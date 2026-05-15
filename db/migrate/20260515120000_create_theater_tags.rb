class CreateTheaterTags < ActiveRecord::Migration[6.1]
  def change
    create_table :theater_tags do |t|
      t.integer :theater_id, null: false
      t.string :name, null: false

      t.timestamps
    end
    add_index :theater_tags, :theater_id
    add_index :theater_tags, :name
    add_foreign_key :theater_tags, :theaters, on_delete: :cascade
  end
end
