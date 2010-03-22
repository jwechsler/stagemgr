class Performance < ActiveRecord::Base
  PERFORMANCE_STATUSES = ['Active',  'Inactive']
  validates_inclusion_of :status,        :in => PERFORMANCE_STATUSES
  validates_uniqueness_of :performance_code, :scope => :production_id
  validates_each :performance_time do |record, attr, value|
    record.errors.add attr, 'has already been taken' if record.production.performances.any?{|p|p.performance_date==record.performance_date && p.performance_time==record.performance_time}
  end
  validates_presence_of :performance_code
  validates_presence_of :performance_date
  validates_presence_of :performance_time
  belongs_to :production
  has_and_belongs_to_many :ticket_classes
  has_many :line_items
  has_many :ticket_class_allocations
  before_validation_on_create :set_defaults
  before_validation :clean_values
  accepts_nested_attributes_for :ticket_class_allocations
  
  def populate_ticket_class_allocations
    self.ticket_class_allocations.each{|tca|tca.performance=self}
    (self.production.ticket_classes - self.ticket_class_allocations.map{|tca|tca.ticket_class}).each do |ticket_class|
      self.ticket_class_allocations << TicketClassAllocation.new({:ticket_class=>ticket_class, :performance=>self})
    end
  end
  
  def set_defaults
    self.performance_date = Date.today if self.performance_date.nil?
    self.performance_time = Time.now if self.performance_time.nil?
  end
  
  def clean_values
    self.performance_code.upcase!
    self.performance_date=Date.parse(self.performance_date.to_s)
  end
end
