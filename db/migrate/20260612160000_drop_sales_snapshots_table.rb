class DropSalesSnapshotsTable < ActiveRecord::Migration[6.1]
  def change
    drop_table :sales_snapshots do |t|
      t.date :as_of_date, null: false
      t.integer :production_stat_id
      t.float :advance_sales, default: 0.0
      t.integer :advance_seats, default: 0
      t.float :daily_sales, default: 0.0
      t.float :sales_to_date, default: 0.0
      t.integer :seats_to_date, default: 0.0
      t.timestamps
    end
  end
end
