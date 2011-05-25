class Performance < ActiveRecord::Base
  using_access_control

  PERFORMANCE_STATUSES = ['Active',  'Inactive', 'Private']

  belongs_to               :production
  has_many                 :ticket_classes, :through=>:ticket_class_allocations
  has_many                 :line_items, :through=>:orders
  has_many                 :orders
  has_many                 :ticket_class_allocations

  validates_inclusion_of   :status,            :in => PERFORMANCE_STATUSES
  validates_uniqueness_of  :performance_code
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
  
  def number_of_tickets_left
    self.production.capacity - self.orders.inject(0){|sum,order| sum + order.line_items.sum(:ticket_count) }
  end
  
  def sold_out?
    self.number_of_tickets_left <= 0
  end 
  
  def happening_soon?
    at = self.performance_at
    (Time.now < at) && (Time.now + 3.hours > at)
  end
  
  def performance_at
    Time.parse(self.performance_date.to_s(:default) + " " + self.performance_time.to_s(:hour_min))
  end
  
  def near_capacity?
    self.number_of_tickets_left <= 9
  end
  
  def populate_ticket_class_allocations
    self.ticket_class_allocations.each{|tca|tca.performance=self}
    (self.production.ticket_classes - self.ticket_class_allocations.map{|tca|tca.ticket_class}).map do |ticket_class|
      self.ticket_class_allocations.build({:ticket_class=>ticket_class, :performance=>self})
    end
  end
  
  def to_s
    "#{self.production.name} [#{datetime_s}] (#{number_of_tickets_left} Tickets Left)"
  end
  
  def to_short_s
    "#{self.production.name} on #{datetime_s}"
  end
  
  def datetime_s
    "#{self.performance_date.strftime('%m/%d')} #{self.performance_time.strftime('%H:%M')}"
  end

  def self.search_by_code(code)
    where("LOWER(performance_code) LIKE ?", '%'+code.to_s.downcase + '%').
      where("status != 'Inactive'").
      order("performance_code ASC").
      limit(10)
  end

  private
  
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
    self.performance_code.upcase! if self.performance_code
  end
end
