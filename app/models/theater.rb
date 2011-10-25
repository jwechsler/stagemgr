 class Theater < ActiveRecord::Base
  using_access_control

  THEATER_CLASSES  = ['Default', 'Resident Company', 'Visiting Company', 'Guest Artist']
  THEATER_STATUSES = ['Active',  'Inactive']
  validates_inclusion_of :theater_class, :in => THEATER_CLASSES
  validates_inclusion_of :status,        :in => THEATER_STATUSES
  validates_uniqueness_of :name
  validates_presence_of :name

  has_many :productions
  has_many :special_offers
  has_many :flex_pass_offers
  has_many :orders
  has_many :address_tags
  has_and_belongs_to_many :users#, :as=>:owners
  
  has_attached_file :logo
  
  def class_display
    return theater_class == 'Default' ? '' : theater_class
  end
  
  def to_s
    return self.name
  end

  def self.allowed
    (Authorization.current_user.respond_to?('is_theater_user?') && Authorization.current_user.is_theater_user?) ? Theater.where("status != 'Inactive' and id in (?)",[Authorization.current_user.theater_ids]) : Theater.where("status != 'Inactive'")
  end

  def is_default?
    self.theater_class == 'Default'
  end

  def is_resident?
    self.theater_class == 'Resident Company'
  end
end
