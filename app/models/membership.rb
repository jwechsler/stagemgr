class Membership < ActiveRecord::Base
  attr_accessible :membership_offer_id, :member_since, :order_id, :address_id, :member_code, :status

  has_many :membership_orders
  has_one :address

end
