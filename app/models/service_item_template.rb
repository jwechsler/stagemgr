class ServiceItemTemplate < ActiveRecord::Base

  validates :name, uniqueness:true
  validates_numericality_of :amount
  validates_presence_of :description

  before_validation :set_internal_description

  def attributes_for_service_item
    {description: self.description, internal_description: self.internal_description,
     amount: self.amount, facility_fee: self.facility_fee}
  end

  def self.selectable
    ServiceItemTemplate.order(:name).where(user_selectable:true)
  end

  def name_and_description
    "#{self.name}: #{self.internal_description}"
  end

  private
  def set_internal_description
    if (self.internal_description.blank?)
      self.internal_description = description
    end
  end

end
