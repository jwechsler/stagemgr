class Payment < ActiveRecord::Base
  belongs_to :order
  validates_numericality_of :amount
  default_scope :order=>'created_at asc'
  def payment_type=(string)
    self.type=string
  end
end