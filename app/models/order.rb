class Order < ActiveRecord::Base
  ORDER_STATUSES = ['Held', 'Processed', 'Refunded', 'Canceled']
  has_many :line_items

  validates_inclusion_of   :status,            :in => ORDER_STATUSES
  
  accepts_nested_attributes_for  :line_items
   
  
end
