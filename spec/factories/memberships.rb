FactoryGirl.define do

  factory :membership do
    profile_id 'REMOTE_PROFILE_ID'
    status Membership::ACTIVE
  end

end
