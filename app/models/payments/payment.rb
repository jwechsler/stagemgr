class Payment < ActiveRecord::Base
  belongs_to :order
  validates_numericality_of :amount
  attr_accessor :card_number
  attr_accessor :card_verification_number
  def payment_type=(string)
    self.type=string
  end
end