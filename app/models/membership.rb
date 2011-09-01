class Membership < ActiveRecord::Base

  MEMBERSHIP_STATUSES = (
    ACTIVE, EXPIRED =
    "Active","Expired"
  )
  attr_accessible :membership_offer_id, :member_since, :order_id, :address_id, :member_code, :status, :profile_id

  has_many :membership_line_items, :foreign_key=>:membership_id
  belongs_to :address
  belongs_to :membership_offer
  validates_presence_of :address
  before_validation :create_code, :on=>:create


  def verify_applicable_for(order)
    if !self.membership_offer.tickets_per_performance.nil?
      perfs = Order.where("performance_id = ? and id in (select order_id from payments where type = 'MembershipPayment' and membership_id = ? and order_id != ?)", order.performance_id, self.id,order.id)
      raise Exceptions::TooManyTicketsForMembership.new("This membership allows you #{self.membership_offer.tickets_per_performance} seat#{'s' if self.membership_offer.tickets_per_performance > 1} per performance") if self.membership_offer.tickets_per_performance < perfs.inject(0) { |sum, o1| sum += o1.membership_payments.inject(0) { |sum, p| sum += p.number_of_tickets } }
    end
  end

  def create_code(size = 6)
    charset = %w{ 2 3 4 6 7 9 A C D E F G H J K L M N P Q R T V W X Y Z}
    while self.member_code.nil? || !FlexPass.find_by_code(self.member_code).nil?
      self.member_code = "TW-#{(0...size).map{ charset.to_a[rand(charset.size)] }.join}"
    end
  end

  def current_status
    gateway ||= ActiveMerchant::Billing::PaypalRecurringGateway.new(:login=>$PAYPAL_LOGIN,
                                                                            :password=>$PAYPAL_PASSWORD)

    response = gateway.get_profile_details(self.profile_id)

    response.params["profile_status"][0..-8]

  end

  def is_active?
    self.current_status == ACTIVE
  end
end
