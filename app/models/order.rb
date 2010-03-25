class Order < ActiveRecord::Base
  ORDER_STATUSES = ['Held', 'Processed', 'Refunded']
  has_many :line_items

  validates_inclusion_of   :status,            :in => ORDER_STATUSES
  
end
