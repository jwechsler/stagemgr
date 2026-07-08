class CreateFestivals < ActiveRecord::Migration[6.1]
  def change
    create_table :festivals do |t|
      t.string :name, null: false
      t.string :slug
      t.text :description
      t.string :short_description
      t.date :starts_on
      t.date :ends_on
      t.string :status, null: false, default: 'Active'
      t.boolean :landing_page_enabled, null: false, default: false

      t.timestamps
    end
    add_index :festivals, :slug, unique: true
    add_index :festivals, :status
  end
end
