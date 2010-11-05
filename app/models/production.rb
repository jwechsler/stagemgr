class Production < ActiveRecord::Base
  PRODUCTION_STATUSES = ['Active',  'Private', 'Inactive' ]
  validates_inclusion_of :status,        :in => PRODUCTION_STATUSES
  validates_presence_of :theater, :name
  validates_uniqueness_of :production_code
  validates_length_of :production_code, :in=>1..5
  validates_numericality_of :capacity

  belongs_to :theater
  has_many :special_offers
  has_many :performances
  has_many :ticket_classes
  has_many :line_items
  before_validation :clean_values
  
  def to_s
    "#{self.theater.name}, #{self.name}"
  end
  
  def rest_path
    [self.theater,self]
  end
  
  def running_dates
    self.first_preview_at.strftime('%B %d, %Y') + " through " + self.closing_at.strftime('%B %d, %Y')
  end
  
  def <=>(other)
      [PRODUCTION_STATUSES.index(self.status), self.opening_at, self.name] <=> [PRODUCTION_STATUSES.index(other.status), other.opening_at, other.name]
  end
  
  private 
  def clean_values
    self.production_code.upcase! unless self.production_code.nil?
  end
  
end
