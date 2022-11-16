class CreatePaymentTypes < ActiveRecord::Migration[4.2]
  def self.up
    create_table :payment_types do |t|
      t.string :display_name

      t.timestamps
    end
  end

  def self.down
    drop_table :payment_types
  end
end
