class Payment < ActiveRecord::Base
  acts_as_audited

  belongs_to :order
  validates_numericality_of :amount, :unless => :number_of_tickets
  validates_numericality_of :number_of_tickets, :unless => :amount
  default_scope :order=>'created_at asc'
  before_save :set_processed_on

  def processing_fee
    return 0
  end

  def payment_type=(string)
    self.type=string
  end
  def process!
    self.processed_on = Date.today
    self.save!
  end
  def self.descendants
    result = []
    ObjectSpace.each_object(Class).each { |c| result << c if c < Payment }
    result
  end

  protected
  def set_processed_on
    self.processed_on = Date.today if (self.new_record? || self.amount_changed?)
  end

end
