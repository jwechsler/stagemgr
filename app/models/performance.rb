class Performance < ActiveRecord::Base
  PERFORMANCE_STATUSES = ['Active',  'Inactive']
  validates_inclusion_of :status,        :in => PERFORMANCE_STATUSES
  validates_uniqueness_of :performance_code, :scope => :production_id
  validates_presence_of :performance_code
  validates_presence_of :performance_date
  validates_presence_of :performance_time
  belongs_to :production
  has_and_belongs_to_many :ticket_classes
  has_many :line_items
  before_validation_on_create :set_defaults
  
  private
  def set_defaults
    self.performance_date = Date.today if self.performance_date.nil?
    self.performance_time = Time.now if self.performance_time.nil?
  end
end
