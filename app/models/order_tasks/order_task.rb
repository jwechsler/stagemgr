class OrderTask < ActiveRecord::Base
  acts_as_audited

  belongs_to :order

  validates_presence_of :order

end
