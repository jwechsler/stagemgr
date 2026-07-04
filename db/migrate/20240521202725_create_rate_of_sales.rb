class CreateRateOfSales < ActiveRecord::Migration[6.1]
  def change
    create_table :rate_of_sales do |t|
      t.date :day_of_sale
      t.integer :production_id, null: false
      t.integer :total_single_tickets
      t.integer :total_complimentary_tickets
      t.decimal :gross_sales, precision: 8, scale: 2
      t.decimal :processing_fees, precision: 8, scale: 2

      t.timestamps
    end

    add_index :rate_of_sales, %i[day_of_sale production_id], unique: true
    add_foreign_key :rate_of_sales, :productions, column: :production_id
  end
end
