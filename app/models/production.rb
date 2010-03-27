class Production < ActiveRecord::Base
  PRODUCTION_STATUSES = ['Active',  'Inactive']
  validates_inclusion_of :status,        :in => PRODUCTION_STATUSES
  validates_presence_of :theater, :name
  validates_uniqueness_of :production_code
  validates_length_of :production_code, :in=>1..5
  validates_numericality_of :capacity
  validates_each :capacity do |record, attr, value|
    max_limit = record.performances.max{|performance| performace.ticket_classes_allocations.maximum(:ticket_limit) }
    record.errors.add attr, 'must be greater than the limit of all ticket classes' if !max_limit.nil? && value <= max_limit
  end

  belongs_to :theater
  has_many :performances
  has_many :ticket_classes
  has_many :line_items
  before_validation :clean_values
  
  private 
  def clean_values
    self.production_code.upcase! unless self.production_code.nil?
  end
end
