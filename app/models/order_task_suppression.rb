class OrderTaskSuppression < ActiveRecord::Base
  # @todo can delete permanently once you remember why...
  # removed for 2.5 upgrade
  # may only be useful for factories?
  # attr_accessible :method_name, :task_type

  belongs_to :payment_method
end
