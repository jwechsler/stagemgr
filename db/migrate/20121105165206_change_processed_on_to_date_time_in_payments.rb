class ChangeProcessedOnToDateTimeInPayments < ActiveRecord::Migration[4.2]
  def change
    change_column :payments, :processed_on, :datetime
  end
end
