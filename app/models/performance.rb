class Performance < ActiveRecord::Base
  PERFORMANCE_STATUSES = ['Active',  'Inactive']
  validates_inclusion_of :status,        :in => PERFORMANCE_STATUSES
  belongs_to :production
  has_and_belongs_to_many :ticket_classes
  has_many :line_items
end
