class SpecialOffer < ActiveRecord::Base
  validates_presence_of :type, :code
  validates_numericality_of :amount, :null=>false
  validates_uniqueness_of :code
  validate do |record|
    self.errors << 'Must be related to something' unless record.theater || record.production || record.performance || record.ticket_class
  end
  
  belongs_to :theater
  belongs_to :production
  belongs_to :performance
  belongs_to :ticket_class
  
  
  def calculate_discount(order)
    raise 'Inimplemented'
  end
  
end
