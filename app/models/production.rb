class Production < ActiveRecord::Base
  PRODUCTION_STATUSES = ['Active',  'Inactive']
  validates_inclusion_of :status,        :in => PRODUCTION_STATUSES
  validates_presence_of :theater, :name

  belongs_to :theater
  has_many :performances
  has_many :ticket_classes
end
