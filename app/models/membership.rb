class Membership < ActiveRecord::Base

  MEMBERSHIP_STATUSES = (
    ACTIVE, EXPIRED =
    "Active","Expired"
  )
  attr_accessible :membership_offer_id, :member_since, :order_id, :address_id, :member_code, :status

  has_many :membership_line_items, :foreign_key=>:membership_id
  belongs_to :address
  belongs_to :membership_offer
  validates_presence_of :address
  before_validation :create_code, :on=>:create


  def create_code(size = 6)
    charset = %w{ 2 3 4 6 7 9 A C D E F G H J K L M N P Q R T V W X Y Z}
    while self.member_code.nil? || !FlexPass.find_by_code(self.member_code).nil?
      self.member_code = "TW-#{(0...size).map{ charset.to_a[rand(charset.size)] }.join}"
    end
  end
end
