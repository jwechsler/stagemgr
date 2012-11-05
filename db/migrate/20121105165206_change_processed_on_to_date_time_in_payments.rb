class ChangeProcessedOnToDateTimeInPayments < ActiveRecord::Migration
  def change
    change_column :payments, :processed_on, :datetime
  end

end
