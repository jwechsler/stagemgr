class AddBillingCyclesToPledge < ActiveRecord::Migration
  def change
    add_column :pledges, :number_cycles_remaining, :integer
    add_column :pledges, :total_billing_cycles, :integer
    add_column :pledges, :recurring_amount, :float
  end
end
