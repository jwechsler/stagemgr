class CreateProductionStats < ActiveRecord::Migration[4.2]
  def change
    create_table :production_stats do |t|
      t.integer :production_id
      t.float :total_ticket_sales
      t.float :average_ticket_price
      t.integer :total_comps
      t.integer :number_of_tickets

      t.timestamps
    end
    add_index :production_stats, :production_id
  end
end
