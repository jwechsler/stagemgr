class Performance < ActiveRecord::Base
  PERFORMANCE_STATUSES = ['Active',  'Inactive']
  validates_inclusion_of :status,        :in => PERFORMANCE_STATUSES
  validates_uniqueness_of :performance_code, :scope => :production_id
  validates_presence_of :performance_code
  belongs_to :production
  has_and_belongs_to_many :ticket_classes
  has_many :line_items
end
