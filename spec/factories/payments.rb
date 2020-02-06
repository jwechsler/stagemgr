FactoryBot.define do
  sequence :transaction_id do |n|
    "TXN#{n}"
  end
  factory :payment do
    amount { 0.0 }

    factory :cash_payment, :parent=>:payment, :class=>'CashPayment' do
      payment_type factory: :cash_payment_type
      

    end

    factory :membership_payment, :parent=>:payment, :class=>'MembershipPayment' do
      payment_type factory: :membership_payment_type
      
    end

    factory :flex_pass_payment, :class=>'FlexPassPayment', :parent=>:payment do
      payment_type factory: :flex_pass_payment_type
      
    end

    factory :credit_card_payment, :class=>'CreditCardPayment', :parent=>:payment do
      transaction_id
      payment_type factory: :credit_card_payment_type
      
    end

    factory :external_payment, :parent=>:payment, :class=>'ExternalPayment' do
      payment_type factory: :external_payment_type
    end
    
  end
end
