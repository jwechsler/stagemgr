class OrderTaskSuppression < ActiveRecord::Base
  attr_accessible :method_name, :task_type

  belongs_to :payment_method
end
