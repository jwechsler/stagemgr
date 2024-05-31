# db/migrate/20240525123456_create_house_counts.rb
class CreateHouseCounts < ActiveRecord::Migration[6.1]
  def change
    create_table :house_counts do |t|
      t.references :performance, type: :integer, null: false, foreign_key: true
      t.integer :total_seats, null: false, default: 0
      t.integer :sold_seats, null: false, default: 0
      t.integer :available_seats, null: false, default: 0
      t.timestamps
    end
  end
end
