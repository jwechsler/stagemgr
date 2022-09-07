class TidyUpOrders < ActiveRecord::Migration[4.2]
  def self.up
    add_column :orders, :payment_type, :string
    
    remove_column :orders, :first_name
    remove_column :orders, :last_name
    remove_column :orders, :billing_address_line1
    remove_column :orders, :billing_address_line2
    remove_column :orders, :billing_address_city
    remove_column :orders, :billing_address_state
    remove_column :orders, :billing_address_zipcode
    remove_column :orders, :email
    remove_column :orders, :on_mailing_list
    
    remove_column :orders, :card_last_four
    remove_column :orders, :card_type
    remove_column :orders, :card_expiration_year
    remove_column :orders, :card_expiration_month
    remove_column :orders, :confirmation_code
  end

  def self.down
    remove_column :orders, :payment_type
    
    add_column :orders, :first_name                 , :string 
    add_column :orders, :last_name                  , :string 
    add_column :orders, :billing_address_line1      , :string 
    add_column :orders, :billing_address_line2      , :string 
    add_column :orders, :billing_address_city       , :string 
    add_column :orders, :billing_address_state      , :string 
    add_column :orders, :billing_address_zipcode    , :string 
    add_column :orders, :email                      , :string 
    add_column :orders, :on_mailing_list            , :boolean
    
    add_column :orders, :card_last_four             , :integer 
    add_column :orders, :card_type                  , :string  
    add_column :orders, :card_expiration_year       , :integer 
    add_column :orders, :card_expiration_month      , :integer 
    add_column :orders, :confirmation_code          , :string  
  end
end
