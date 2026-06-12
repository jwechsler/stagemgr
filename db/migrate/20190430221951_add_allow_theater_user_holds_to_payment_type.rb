class AddAllowTheaterUserHoldsToPaymentType < ActiveRecord::Migration[4.2]
  def change
    add_column :payment_types, :allow_theater_user_holds, :boolean, :default => false
  end
end
