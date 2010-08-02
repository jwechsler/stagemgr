class Theater < ActiveRecord::Base
  THEATER_CLASSES  = ['Default', 'Resident Company', 'Visiting Company', 'Guest Artist']
  THEATER_STATUSES = ['Active',  'Inactive']
  validates_inclusion_of :theater_class, :in => THEATER_CLASSES
  validates_inclusion_of :status,        :in => THEATER_STATUSES
  validates_uniqueness_of :name
  validates_presence_of :name

  has_many :productions
  has_many :special_offers
  has_many :flex_pass_offers
  has_and_belongs_to_many :users#, :as=>:owners
  
  has_attached_file :logo
  
  def class_display
    return theater_class == 'Default' ? '' : theater_class
  end
end
