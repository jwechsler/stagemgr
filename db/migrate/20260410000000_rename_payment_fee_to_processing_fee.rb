class RenamePaymentFeeToProcessingFee < ActiveRecord::Migration[6.1]
  def up
    rename_column :payments, :payment_fee, :processing_fee
    change_column_default :payments, :processing_fee, nil
    Payment.update_all(processing_fee: nil)
  end

  def down
    Payment.update_all(processing_fee: nil)
    change_column_default :payments, :processing_fee, 0.0
    rename_column :payments, :processing_fee, :payment_fee
  end
end
