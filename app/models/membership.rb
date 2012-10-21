class Membership < ActiveRecord::Base

  MEMBERSHIP_STATUSES = (
  ACTIVE, EXPIRED, PENDING, CANCELED, SUSPENDED =
      "Active", "Expired", "Pending", "Canceled", "Suspended"
  )
  attr_accessible :membership_offer_id, :member_since, :order_id, :address_id, :member_code, :status, :profile_id

  has_one :membership_line_item, :foreign_key=>:membership_id
  has_many :special_offers, :dependent=>:destroy
  before_destroy :cancel_future_reservations
  belongs_to :address
  belongs_to :membership_offer
  validates_presence_of :address
  before_validation :create_code, :on=>:create
  has_many :membership_payments
  before_save :release_reservations_on_cancel_or_suspend

  def verify_applicable_for(order)
    if !self.membership_offer.tickets_per_performance.nil?
      perfs = Order.where("performance_id = ? and id in (select order_id from payments where type = 'MembershipPayment' and membership_id = ?)", order.performance_id, self.id)
      raise Exceptions::TooManyTicketsForMembership.new("This membership allows you #{self.membership_offer.tickets_per_performance} seat#{'s' if self.membership_offer.tickets_per_performance > 1} per performance") if self.membership_offer.tickets_per_performance < perfs.inject(0) { |sum, o1| sum += o1.membership_payments.inject(0) { |sum, p| sum += p.number_of_tickets } }
    end
    if order.membership_payments.sum{|li| li.number_of_tickets} > 0
      prods = Production.count(:conditions=>["exists (select * from performances, orders orders_old, orders, payments, line_items, ticket_classes
        where line_items.order_id = orders.id and payments.type = 'MembershipPayment' and
            ticket_classes.id = line_items.ticket_class_id and ticket_classes.class_code = ? and
            payments.order_id = orders.id and orders.performance_id = performances.id and
            performances.production_id = productions.id and payments.membership_id = ? and
            orders.id != ? and productions.id = ? and orders.status in (?))",
                                           self.membership_offer.use_ticket_class_code,
                                           self.id, order.id, order.performance.production_id, Order.attending_statuses])
    raise Exceptions::RepeatVisitsAtDoorOnly.new("Tickets for repeat trips to the same show are based on availability at the door on the day of performance.  To see this show again, just come to the box office with your member pass on #{order.performance.performance_date.strftime("%B %d")} at #{(order.performance.performance_time-30.minutes).strftime("%I:%M%p")}.") if prods > 0
    end
  end

  def create_code(size = 6)
    charset = %w{ 2 3 4 6 7 9 A C D E F G H J K L M N P Q R T V W X Y Z}
    while self.member_code.nil? || !FlexPass.find_by_code(self.member_code).nil?
      self.member_code = "TW-#{(0...size).map { charset.to_a[rand(charset.size)] }.join}"
    end
  end

  def get_profile_data
    gateway ||= PaymentProcessing.recurring_gateway

    response = gateway.status_recurring(self.profile_id)
    response.params
  end

  def update_from_profile
    response = self.get_profile_data
    self.number_cycles_completed = response["number_cycles_completed"] unless response["number_cycles_completed"].blank?
    self.next_billing_date = response["next_billing_date"].to_date  unless response["next_billing_date"].blank?
    self.aggregate_amount = response["aggregate_amount"]  unless response["aggregate_amount"].blank?
    self.failed_payment_count = response["failed_payment_count"] unless response["failed_payment_count"].blank?
    self.outstanding_balance = response["outstanding_balance"].to_f unless response["outstanding_balance"].blank?
    cycles = self.number_cycles_completed
    cycles ||=0
    profile_status = response["profile_status"][0..-8]  unless response["profile_status"].blank?
    self.status = case
      when (profile_status == ACTIVE)
        ACTIVE
      when (profile_status == PENDING) || (profile_status == ACTIVE && cycles == 0)
        PENDING
      when (['Cancelled',CANCELED].include?(profile_status))
        CANCELED
      when (profile_status == SUSPENDED)
        profile_status
      else
        "Other"
    end
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

  def source_order
    self.membership_line_item.order
  end

  def inactive?
    [Membership::CANCELED, Membership::SUSPENDED].include?(self.status)
  end

  private

  def release_reservations_on_cancel_or_suspend
    if self.status_changed? && self.inactive?
      cancel_future_reservations
    end
  end

  def cancel_future_reservations
    self.membership_payments.each do |payment|
      o = payment.order
      d = o.reservation_date
      unless d.nil? || d < Time.now || o.refunded?
        o.refund!
      end
    end
    true
  end
end

# my_emma add on
class Membership

  after_save :update_membership_list_subscription, :if => :status_changed_for_myemma?

  def status_changed_for_myemma?
    self.status_changed? && !MyEmma.disabled?
  end

  def update_my_emma_membership
    if self.status_changed?
      if self.inactive?
        self.remove_from_membership_list
      else
        self.add_to_membership_list
      end
    end

  end

  def add_to_membership_list
    unless self.membership_offer.myemma_group.nil?
      begin
        member = MyEmma::Member.new
        member.name_first = self.address.first_name
        member.name_last = self.address.last_name
        member.email = self.address.email
        member.address = self.address.line1
        member.city = self.address.city
        member.state = self.address.state
        member.postal_code = self.address.zipcode
        member.save([self.membership_offer.myemma_group])
      rescue Exception=>e
        Rails.logger.error("Could not update membership mailing list for address ##{self.address.id}, #{e.message}")
      end
    end
  end

  def remove_from_membership_list
    group_id = self.membership_offer.myemma_group
    unless group_id.blank? || self.address.email.blank? || self.address.is_current_member?
      begin
        member = MyEmma::Member.find_by_email(self.address.email)

        unless member.nil?
          group = MyEmma::Group.find(group_id)
          group.remove_members(member)
        end
      rescue Exception=>e
        Rails.logger.error("Could not update membership mailing list for address ##{self.address.id}, #{e.message}")
      end
    end
  end

  def update_membership_list_subscription
    if self.inactive?
      self.remove_from_membership_list
    else
      self.add_to_membership_list
    end
    true
  end


end

