class AddNewSubscriptionDataToMembership < ActiveRecord::Migration
  def change
    add_column :memberships, :start_date, :date
    add_column :memberships, :ended_at, :date
    remove_column :memberships, :number_cycles_remaining
    remove_column :memberships, :number_cycles_completed
    remove_column :memberships, :failed_payment_count
    remove_column :memberships, :outstanding_balance
    add_column :memberships, :cancel_at_period_end, :boolean, :default=>false
  end
end
