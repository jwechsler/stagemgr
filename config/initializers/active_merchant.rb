require 'active_merchant'
#is the api key and transaction id for a authorize.net test account?
ActiveMerchant::Billing::Base.mode = :test
ACTIVE_MERCHANT_LOGIN='2Kay9XwBt65p'
ACTIVE_MERCHANT_PASSWORD='49Yq8s6L84N7jJ3M'
#should the requests be made in test mode (can run test against a real server)
ACTIVE_MERCHANT_TEST_MODE=true

