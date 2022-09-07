class AddFinalPaymentDueDateToMembership < ActiveRecord::Migration[4.2]
  def change
    add_column :memberships, :final_payment_due_date, :date
  end
end
