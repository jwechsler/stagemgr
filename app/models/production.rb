class Production < ActiveRecord::Base
  PRODUCTION_STATUSES = ['Active',  'Inactive']
  validates_inclusion_of :status,        :in => PRODUCTION_STATUSES
  validates_presence_of :theater, :name
  validates_uniqueness_of :production_code
  validates_length_of :production_code, :in=>1..5
  validates_numericality_of :capacity
  validates_each :capacity do |record, attr, value|
    max_limit = record.performances.map{|performance| performance.ticket_class_allocations.maximum(:ticket_limit) }.max
    if !max_limit.nil? then
       record.errors.add attr, 'must be greater than the limit of all ticket classes' if !max_limit.nil? && value <= max_limit
    end
  end

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
  
  private 
  def clean_values
    self.production_code.upcase! unless self.production_code.nil?
  end
  
end
