class MovePaymentsToDecimal < ActiveRecord::Migration[4.2]
  def change
    rename_column :payments, :amount, :amount_old
    rename_column :payments, :payment_fee, :payment_fee_old
    add_column :payments, :payment_fee, :decimal, precision: 8, scale: 2, default: 0.0
    add_column :payments, :amount, :decimal, precision: 8, scale: 2, default: 0.0
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE PAYMENTS SET PAYMENT_FEE = PAYMENT_FEE_OLD, AMOUNT = AMOUNT_OLD;
        SQL
      end
      dir.down do
        execute <<-SQL
          UPDATE PAYMENTS SET PAYMENT_FEE_OLD = PAYMENT_FEE, AMOUNT_OLD = AMOUNT;
        SQL
      end
    end
    remove_column :payments, :amount_old, :float
    remove_column :payments, :payment_fee_old, :float
  end
end
