class OrderTaskSuppression < ApplicationRecord

  belongs_to :payment_method,  optional: true
end
