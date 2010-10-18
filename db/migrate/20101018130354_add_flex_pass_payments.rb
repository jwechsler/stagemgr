class AddFlexPassPayments < ActiveRecord::Migration
  def self.up
    add_column :payments, :flex_pass_id, :integer
    add_column :payments, :number_of_tickets, :integer
  end

  def self.down
    remove_column :payments, :flex_pass_id
    remove_column :payments, :number_of_tickets
  end
end
