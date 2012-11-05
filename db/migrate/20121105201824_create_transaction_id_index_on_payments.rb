class CreateTransactionIdIndexOnPayments < ActiveRecord::Migration
  def up
    add_index :payments, :transaction_id
  end

  def down
    remove_index :payments, :transaction_id
  end
end
