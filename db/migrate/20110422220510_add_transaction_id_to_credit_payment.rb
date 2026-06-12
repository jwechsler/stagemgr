class AddTransactionIdToCreditPayment < ActiveRecord::Migration[4.2]
  def self.up
    add_column :payments, :transaction_id, :string
  end

  def self.down
    remove_column :payments, :transaction_id
  end
end
