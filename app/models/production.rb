class Production < ActiveRecord::Base
  PRODUCTION_STATUSES = ['Active',  'Inactive']
  validates_inclusion_of :status,        :in => ['Active',  'Inactive']
  validates_presence_of :theater

  belongs_to :theater
  has_many :performances
end
