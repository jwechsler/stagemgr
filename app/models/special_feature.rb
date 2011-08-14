class SpecialFeature < ActiveRecord::Base

  SPECIAL_FEATURE_STATUSES = (
      ACTIVE, INACTIVE = 'Active', 'Inactive'
  )

  attr_accessible :short_name, :description
  has_and_belongs_to_many :performances

  def to_s
    self.short_name
  end
end
