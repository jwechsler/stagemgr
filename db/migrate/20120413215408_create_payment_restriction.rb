class CreatePaymentRestriction < ActiveRecord::Migration
  def self.up
    create_table :payment_restrictions do |t|
          t.integer :performance_id
          t.integer :payment_type_id
          t.timestamps
        end
  end

  def self.down
    drop_table :payment_restrictions
  end
end
