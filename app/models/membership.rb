class Membership < ActiveRecord::Base

  MEMBERSHIP_STATUSES = (
  ACTIVE, EXPIRED, PENDING, CANCELED =
      "Active", "Expired", "Pending", "Canceled"
  )
  attr_accessible :membership_offer_id, :member_since, :order_id, :address_id, :member_code, :status, :profile_id

  has_one :membership_line_item, :foreign_key=>:membership_id
  belongs_to :address
  belongs_to :membership_offer
  validates_presence_of :address
  before_validation :create_code, :on=>:create


  def verify_applicable_for(order)
    if !self.membership_offer.tickets_per_performance.nil?
      perfs = Order.where("performance_id = ? and id in (select order_id from payments where type = 'MembershipPayment' and membership_id = ?)", order.performance_id, self.id)
      raise Exceptions::TooManyTicketsForMembership.new("This membership allows you #{self.membership_offer.tickets_per_performance} seat#{'s' if self.membership_offer.tickets_per_performance > 1} per performance") if self.membership_offer.tickets_per_performance < perfs.inject(0) { |sum, o1| sum += o1.membership_payments.inject(0) { |sum, p| sum += p.number_of_tickets } }
    end
  end

  def create_code(size = 6)
    charset = %w{ 2 3 4 6 7 9 A C D E F G H J K L M N P Q R T V W X Y Z}
    while self.member_code.nil? || !FlexPass.find_by_code(self.member_code).nil?
      self.member_code = "TW-#{(0...size).map { charset.to_a[rand(charset.size)] }.join}"
    end
  end

  def get_profile_data
    gateway ||= ActiveMerchant::Billing::PaypalRecurringGateway.new(:login=>$PAYPAL_LOGIN,
                                                                    :password=>$PAYPAL_PASSWORD)

    response = gateway.get_profile_details(self.profile_id)
    response.params
  end

  def update_from_profile
    response = self.get_profile_data
    self.number_cycles_completed = response["number_cycles_completed"] unless response["number_cycles_completed"].blank?
    self.next_billing_date = response["next_billing_date"].to_date  unless response["next_billing_date"].blank?
    self.aggregate_amount = response["aggregate_amount"]  unless response["next_billing_date"].blank?
    self.status = response["profile_status"][0..-8]  unless response["next_billing_date"].blank?
  end

  def update_from_profile!
    self.update_from_profile
    self.save!
    self
  end

  def is_active?
    self.status == ACTIVE
  end

  def is_pending?
    self.status == PENDING
  end
end
