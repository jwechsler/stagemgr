class CreatePayments < ActiveRecord::Migration[4.2]
  def self.up
    create_table :payments do |t|

      #this should be positive for payments and negative for credits
      t.float       :amount

      #for credit card payments
      t.integer     :card_last_four
      t.string      :card_type
      t.integer     :card_expiration_year
      t.integer     :card_expiration_month
      t.string      :confirmation_code

      #for payments to orders
      t.references  :order

      #for refunds
      t.references  :payment
      
      #for STI
      t.string :type

      t.timestamps
    end
  end

  def self.down
    drop_table :payments
  end
end
