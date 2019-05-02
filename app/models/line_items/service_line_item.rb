class ServiceLineItem < LineItem

  validates_numericality_of :amount
  validates_presence_of :description, :facility_fee

  def total
    return self.amount
  end
end
