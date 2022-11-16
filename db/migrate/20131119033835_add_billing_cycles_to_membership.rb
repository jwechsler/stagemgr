class AddBillingCyclesToMembership < ActiveRecord::Migration[4.2]
  def change
    add_column :memberships, :number_cycles_remaining, :integer
    add_column :memberships, :total_billing_cycles, :integer
    add_column :memberships, :recurring_amount, :float
  end
end
