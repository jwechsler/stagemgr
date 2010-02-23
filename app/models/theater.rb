class Theater < ActiveRecord::Base
  THEATER_CLASSES  = ['Default', 'Resident', 'Renter']
  THEATER_STATUSES = ['Active',  'Inactive']
  validates_inclusion_of :theater_class, :in => THEATER_CLASSES
  validates_inclusion_of :status,        :in => THEATER_STATUSES

  has_many :productions
  has_and_belongs_to_many :users#, :as=>:owners
end
