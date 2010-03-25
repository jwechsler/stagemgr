class TicketClass < ActiveRecord::Base
  TICKET_TYPES = ['Fixed', 'Donation', 'Timed']
  validates_inclusion_of :ticket_type,        :in => TICKET_TYPES
  validates_uniqueness_of :class_code
  validates_length_of :class_code, :in=>1..4
  belongs_to :production
  has_many :line_items
  before_validation :clean_values
  validates_numericality_of :minutes_before_show, :allow_nil => true
  validates_each :minutes_before_show do |record, attr, value|
    record.errors.add attr, 'must be less than production capacity' if !value.nil? && value >= self.production.capacity
  end
    
  
  def number_left
    ticket_class_capacity_left = production_capacity_left = self.production.capacity - self.production.line_items.sum(:ticket_count)
    unless self.limit.nil?
      ticket_class_capacity_left = self.limit - self.line_items.sum(:ticket_count)
    end
    return [ticket_class_capacity_left,production_capacity_left].min
  end
  
  private 
  def clean_values
    self.class_code.upcase!
  end
end
