class SetDefaultPaymentTypesPermission < ActiveRecord::Migration
  def up
    execute "update payment_types set allow_for_public = 1 where type in ('CreditCardPaymentType','CashPaymentType','FlexPassPaymentType','MembershipPaymentType')"
  end

  def down
  end
end
