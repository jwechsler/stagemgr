class AddMembershipToPayments < ActiveRecord::Migration[4.2]
  def self.up
    add_column :payments, :membership_id, :integer
  end

  def self.down
    remove_column :payments, :membership_id
  end
end
