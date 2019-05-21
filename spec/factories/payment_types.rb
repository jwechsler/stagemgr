FactoryBot.define do

  factory :credit_card_payment_type do
    display_name     { "Credit Card" }
    initialize_with  { CreditCardPaymentType.find_or_create_by(id:1) }

  end

  factory :cash_payment_type do
    display_name     { "Cash" }
    initialize_with { CashPaymentType.find_or_create_by(id:2)}
  end

  factory :membership_payment_type do
    display_name     { "Membership" }
    initialize_with { MembershipPaymentType.find_or_create_by(id:3)}
   end

  factory :flex_pass_payment_type do
    display_name      { "Flex Pass" }
    initialize_with { FlexPassPaymentType.find_or_create_by(id:4) }
  end

  factory :external_payment_type do
    display_name      { "External Payment" }
    initialize_with { ExternalPaymentType.find_or_create_by(id:5) }
  end

  factory :check_payment_type do
    display_name      { 'Check' }
    initialize_with { CheckPaymentType.find_or_create_by(id:6)}
  end

end