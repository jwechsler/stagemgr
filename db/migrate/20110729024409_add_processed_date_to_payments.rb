class AddProcessedDateToPayments < ActiveRecord::Migration[4.2]
  def self.up
    add_column :payments, :processed_on, :date
    execute 'update payments set processed_on = created_at'
  end

  def self.down
    remove_column :payments, :processed_on
  end
end
