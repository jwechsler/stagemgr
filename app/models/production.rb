class Production < ActiveRecord::Base
  PRODUCTION_STATUSES = ['Active',  'Inactive']
  validates_inclusion_of :status,        :in => PRODUCTION_STATUSES
  validates_presence_of :theater, :name
  validates_uniqueness_of :production_code
  validates_length_of :production_code, :in=>1..5
  validates_numericality_of :capacity, :allow_nil => true

  belongs_to :theater
  has_many :performances
  has_many :ticket_classes
  before_validation :clean_values
  
  private 
  def clean_values
    self.production_code.upcase!
  end
end
