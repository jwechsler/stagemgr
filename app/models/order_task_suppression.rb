class OrderTaskSuppression < ActiveRecord::Base
  attr_accessible :method, :task_type
  belongs_to :payment_method
end
