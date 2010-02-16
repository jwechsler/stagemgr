class CreateProductions < ActiveRecord::Migration
  def self.up
    create_table :productions do |t|
      t.string :name
      t.text :credit_lines
      t.date :first_preview_at
      t.date :press_opening_at
      t.date :opening_at
      t.date :closing_at
      t.text :show_description
      t.integer :capacity
      t.string :additional_information_link
      t.string :status
      t.references :theater

      t.timestamps
    end
  end

  def self.down
    drop_table :productions
  end
end
