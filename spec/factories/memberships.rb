FactoryBot.define do

  factory :membership do
    profile_id PaymentProcessing::BogusResponse::PROFILE_ID
    status Membership::ACTIVE
    membership_offer
  end

end
