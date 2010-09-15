class Payment < ActiveRecord::Base
  belongs_to :order
  validates_numericality_of :amount
  def payment_type=(string)
    self.type=string
  end
end