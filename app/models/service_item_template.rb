class ServiceItemTemplate < ActiveRecord::Base

  validates :name, uniqueness:true

  def attributes_for_service_item
    {description: self.description, amount: self.amount, facility_fee: self.facility_fee}
  end


end
