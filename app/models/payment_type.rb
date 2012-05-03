class PaymentType < ActiveRecord::Base
  has_many :payment_restrictions, :dependent=>:destroy

  def to_label
   self.display_name
  end
end
