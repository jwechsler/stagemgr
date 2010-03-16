class Performance < ActiveRecord::Base
  belongs_to :production
  has_and_belongs_to_many :ticket_classes
  has_many :line_items
  
  
end
