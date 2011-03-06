class Payment < ActiveRecord::Base
  acts_as_audited

  belongs_to :order
  validates_numericality_of :amount, :unless => :number_of_tickets
  validates_numericality_of :number_of_tickets, :unless => :amount
  default_scope :order=>'created_at asc'
  def payment_type=(string)
    self.type=string
  end
end
