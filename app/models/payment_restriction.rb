class PaymentRestriction < ApplicationRecord
  belongs_to :performance, inverse_of: :payment_restrictions
  belongs_to :payment_type, inverse_of: :payment_restrictions
end
