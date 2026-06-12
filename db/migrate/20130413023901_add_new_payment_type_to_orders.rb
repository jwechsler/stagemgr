class AddNewPaymentTypeToOrders < ActiveRecord::Migration[4.2]
  def up
    add_column :orders, :new_payment_type, :integer
    execute 'update orders set new_payment_type = (select id from payment_types where display_name = orders.payment_type)'
    remove_column :orders, :payment_type
    rename_column :orders, :new_payment_type, :payment_type
  end

  def down
    add_column :orders, :old_payment_type, :string
    execute 'update orders set old_payment_type = (select display_name from payment_types where payment_types.id = orders.payment_type'
    remove column :orders, :payment_type
    rename_column :orders, :old_payment_type, :payment_type
  end
end
