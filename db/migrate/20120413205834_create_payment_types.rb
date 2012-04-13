class CreatePaymentTypes < ActiveRecord::Migration
  def self.up
    create_table :payment_types do |t|
      t.string :display_name

      t.timestamps
    end
    ["Credit Card", "Cash", "FlexPass", "Price Override", "Membership"].each { |p| PaymentType.create :display_name=>p }
  end

  def self.down
    drop_table :payment_types
  end
end
