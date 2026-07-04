class CreateOrders < ActiveRecord::Migration[4.2]
  def self.up
    create_table :orders do |t|
      t.references :performance
      t.string :status

      t.string  :first_name
      t.string  :last_name
      t.string  :billing_address_line1
      t.string  :billing_address_line2
      t.string  :billing_address_city
      t.string  :billing_address_state
      t.string  :billing_address_zipcode
      t.string  :email
      t.boolean :on_mailing_list

      t.integer :card_last_four
      t.string  :card_type
      t.integer :card_expiration_year
      t.integer :card_expiration_month
      t.string  :confirmation_code

      t.timestamps
    end
  end

  def self.down
    drop_table :orders
  end
end
