class Performance < ActiveRecord::Base
  PERFORMANCE_STATUSES = ['Active',  'Inactive']

  belongs_to               :production
  has_and_belongs_to_many  :ticket_classes
  has_many                 :line_items
  has_many                 :ticket_class_allocations

  validates_inclusion_of   :status,            :in => PERFORMANCE_STATUSES
  validates_uniqueness_of  :performance_code,  :scope => :production_id
  validates_each           :performance_time do |record, attr, value|
    if record.production.performances.any? do |p|
        p.id != record.id && 
        p.performance_date==record.performance_date && 
        p.performance_time.hour==record.performance_time.hour &&
        p.performance_time.min==record.performance_time.min
      end
      record.errors.add attr, 'has already been taken' 
    end
  end
  validates_presence_of    :performance_code
  validates_presence_of    :performance_date
  validates_presence_of    :performance_time

  before_validation              :clean_values
  accepts_nested_attributes_for  :ticket_class_allocations
  
  def populate_ticket_class_allocations
    self.ticket_class_allocations.each{|tca|tca.performance=self}
    (self.production.ticket_classes - self.ticket_class_allocations.map{|tca|tca.ticket_class}).each do |ticket_class|
      self.ticket_class_allocations << TicketClassAllocation.new({:ticket_class=>ticket_class, :performance=>self})
    end
  end
  
  def clean_values
    self.performance_date = Date.today if self.performance_date.nil?
    self.performance_time = Time.now if self.performance_time.nil?
    self.performance_date = self.performance_date.change( :hour  => 0,
                                  :min   => 0,
                                  :sec   => 0,
                                  :usec  => 0)
    self.performance_time = self.performance_time.change( :year  => self.performance_date.year,
                                  :month => self.performance_date.month,
                                  :day   => self.performance_date.day,
                                  :min   => ((self.performance_time.min.to_i/15)*15),
                                  :sec   => 0,
                                  :usec  => 0)
    self.performance_code.upcase!
  end
end
