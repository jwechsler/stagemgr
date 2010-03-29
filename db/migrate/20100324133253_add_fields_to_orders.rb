class AddFieldsToOrders < ActiveRecord::Migration
  def self.up
    add_column :orders, :status, :string
    add_column :orders, :confirmation_code, :string

    add_column :orders, :first_name, :string
    add_column :orders, :last_name, :string
    add_column :orders, :billing_address_line1, :string
    add_column :orders, :billing_address_line2, :string
    add_column :orders, :billing_address_city, :string
    add_column :orders, :billing_address_state, :string
    add_column :orders, :billing_address_zipcode, :integer
    add_column :orders, :email, :string
    add_column :orders, :on_mailing_list, :boolean
    add_column :orders, :card_last_four, :integer
    add_column :orders, :card_type, :string
  end

  def self.down
  end
end
