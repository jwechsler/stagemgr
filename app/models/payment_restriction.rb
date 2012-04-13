class PaymentRestriction < ActiveRecord::Base
  belongs_to :performance
  belongs_to :payment_type
end
