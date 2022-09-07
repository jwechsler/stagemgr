class PaymentRestriction < ApplicationRecord
  belongs_to :performance
  belongs_to :payment_type
end
