class MakePaymentTypeSingleInheritance < ActiveRecord::Migration[4.2]
  def up
    add_column :payment_types, :type, :string
    execute "update payment_types set type = 'CashPaymentType' where display_name = 'Cash'"
    execute "update payment_types set type = 'CreditCardPaymentType' where display_name = 'Credit Card'"
    execute "update payment_types set type = 'MembershipPaymentType' where display_name = 'Membership'"
    execute "update payment_types set type = 'FlexPassPaymentType' where display_name = 'FlexPass'"
  end

  def down
    remove_column :payment_types, :type, :string
  end

end
