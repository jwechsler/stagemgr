class RemoveReferralCodeFromOrders < ActiveRecord::Migration[6.1]
  def up
    # Copy data from referral_code to marketing_source where marketing_source is empty
    # We need to do this before removing the column
    execute <<-SQL
      UPDATE orders
      SET marketing_source = referral_code
      WHERE referral_code IS NOT NULL
      AND referral_code != ''
      AND (marketing_source IS NULL OR marketing_source = '')
    SQL

    # Log for debugging how many records were affected
    order_class = Class.new(ActiveRecord::Base) { self.table_name = "orders" }
    puts "Migrated #{order_class.where('marketing_source = referral_code').count} records from referral_code to marketing_source"

    # Now remove the column
    remove_column :orders, :referral_code, :string
  end

  def down
    # Add the column back, but we can't restore the data
    add_column :orders, :referral_code, :string
    
    puts "Warning: Data migration is one-way. The referral_code values cannot be restored."
  end
end
