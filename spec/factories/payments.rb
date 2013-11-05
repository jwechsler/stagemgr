FactoryGirl.define do
  sequence :transaction_id do |n|
    "TXN#{n}"
  end
  factory :payment do
    amount 0

    factory :cash_payment, :parent=>:payment, :class=>'CashPayment' do
    end

    factory :membership_payment, :parent=>:payment, :class=>'MembershipPayment' do
    end

    factory :flex_pass_payment, :class=>'FlexPassPayment', :parent=>:payment do
    end

    factory :credit_card_payment, :class=>'CreditCardPayment', :parent=>:payment do
      transaction_id
    end

  end
end
