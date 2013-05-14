class AddPermissionsToPaymentTypes < ActiveRecord::Migration
  def change
    add_column :payment_types, :allow_for_public, :boolean, :default=>false
    add_column :payment_types, :allow_for_box_office, :boolean, :default=>true
  end
end
