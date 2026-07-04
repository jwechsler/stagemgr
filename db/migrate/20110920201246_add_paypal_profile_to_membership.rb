class AddPaypalProfileToMembership < ActiveRecord::Migration[4.2]
  def self.up
    add_column :memberships, :cycles_active, :integer
    add_column :memberships, :aggregate_amount, :decimal, precision: 10, scale: 2
    add_column :memberships, :next_billing_date, :date
    add_column :memberships, :number_cycles_completed, :integer
  end

  def self.down
    remove_column :memberships, :number_cycles_completed
    remove_column :memberships, :next_billing_date
    remove_column :memberships, :aggregate_amount
    remove_column :memberships, :cycles_active
  end
end
