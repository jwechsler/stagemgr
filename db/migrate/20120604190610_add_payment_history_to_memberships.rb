class AddPaymentHistoryToMemberships < ActiveRecord::Migration
  def self.up
    add_column :memberships, :failed_payment_count, :integer
    add_column :memberships, :outstanding_balance, :float
  end

  def self.down
    remove_column :memberships, :outstanding_balance
    remove_column :memberships, :failed_payment_count
  end
end
