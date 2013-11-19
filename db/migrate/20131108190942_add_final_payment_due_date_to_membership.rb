class AddFinalPaymentDueDateToMembership < ActiveRecord::Migration
  def change
    add_column :memberships, :final_payment_due_date, :date
  end
end
