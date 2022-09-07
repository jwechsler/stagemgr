class CreatePledges < ActiveRecord::Migration[4.2]
  def change
    create_table :pledges do |t|
      t.integer :order_id
      t.string  :profile_id
      t.integer :address_id
      t.integer :cycles_active
      t.decimal :aggregate_amount, :precision=>10, :scale=>2
      t.date    :next_billing_date
      t.integer :failed_payment_count
      t.integer :number_cycles_completed
      t.decimal :outstanding_balance, :precision=>10, :scale=>2
      t.string  :status
      t.date    :final_payment_due_date
      t.timestamps
    end
    add_index :pledges, :order_id
    add_index :pledges, :profile_id
    add_index :pledges, :address_id
  end
end
