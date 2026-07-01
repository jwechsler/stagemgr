class OrderTaskSuppression < ApplicationRecord
  belongs_to :payment_type, optional: true
end
