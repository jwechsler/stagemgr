FactoryBot.define do

  factory :credit_card_payment_type do
    initialize_with  { CreditCardPaymentType.find_or_create_by(id:1, display_name: 'Credit Card') }

  end

  factory :cash_payment_type do
    initialize_with { CashPaymentType.find_or_create_by(id:2, display_name: 'Cash')}
  end

  factory :membership_payment_type do
     initialize_with { MembershipPaymentType.find_or_create_by(id:3, display_name: 'Membership')}
   end

  factory :flex_pass_payment_type do
    initialize_with { FlexPassPaymentType.find_or_create_by(id:4, display_name: 'Flex Pass')}
  end

  factory :external_payment_type do
    initialize_with { ExternalPaymentType.find_or_create_by(id:5, display_name: 'External Payment')}
  end

  factory :check_payment_type do
    initialize_with { CheckPaymentType.find_or_create_by(id:6, display_name: 'Check')}
  end

end