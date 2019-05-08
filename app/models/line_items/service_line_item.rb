class ServiceLineItem < LineItem

 validates_numericality_of :amount, :greater_than_or_equal_to=>0
 validates_numericality_of :facility_fee
 validates_presence_of :description, :facility_fee, :amount
 attr_accessor :name

  def total
    return self.amount
  end
end
