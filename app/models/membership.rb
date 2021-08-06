class Membership < ActiveRecord::Base
  include RecurringProfile

  SEATING_REQUESTS = (
    BEST_AVAILABLE, FRONT_ROW, TOWARDS_REAR, ON_AISLE, WHEELCHAIR, STAIRS =
    'Best available (center)', 'Front row', 'Towards rear', 'On aisle', 'Wheelchair', 'No stairs')


  has_one :membership_order, :through=>:membership_line_item
  has_one :membership_line_item, :foreign_key=>:membership_id
  has_many :special_offers, :dependent=>:destroy
  belongs_to :membership_offer

  before_destroy :cancel_future_reservations
  validates_presence_of :membership_offer
  before_validation :create_code, :on=>:create
  has_many :membership_payments
  before_save :release_reservations_on_cancel
  before_save :release_pending_tasks_on_cancel

  def verify_applicable_for(order)
    unless self.membership_offer.tickets_per_performance.nil?
      perfs = Order.where("performance_id = ? and id <> ? and id in (select order_id from payments where type = 'MembershipPayment' and membership_id = ?)", order.id,order.performance_id, self.id)
      raise Exceptions::TooManyTicketsForMembership.new("This membership allows you #{self.membership_offer.tickets_per_performance} seat#{'s' if self.membership_offer.tickets_per_performance > 1} per performance") if self.membership_offer.tickets_per_performance < perfs.inject(0) { |sum, o1| sum += o1.membership_payments.inject(0) { |sum, p| sum += p.number_of_tickets } }
    end
    if order.membership_payments.sum{|li| li.number_of_tickets} > 0
      prod_count = Performance.includes(
        orders: [[ticket_line_items: :ticket_class], :payments]
        ).references(:orders, :payments, :ticket_classes
        ).where(
          'payments.type = \'MembershipPayment\' and payments.membership_id = :membership_id and
          orders.id != :order_id and performances.production_id = :production_id and
          ticket_classes.class_code = :class_code and orders.status in (:attending)',
          class_code:self.membership_offer.use_ticket_class_code,
          membership_id: self.id,
          order_id: order.id,
          production_id: order.performance.production_id,
          attending:Order.attending_statuses
        ).count
    raise Exceptions::RepeatVisitsAtDoorOnly.new("Tickets for repeat trips to the same show are based on availability at the door on the day of performance.  To see this show again, just come to the box office with your member pass on #{order.performance.performance_date.strftime("%B %d")} at #{(order.performance.performance_time-30.minutes).strftime("%I:%M%p")}.") if prod_count > 0
    end
  end

  def create_code(size = 6)
    charset = %w{ 2 3 4 6 7 9 A C D E F G H J K L M N P Q R T V W X Y Z}
    while self.member_code.nil? || !FlexPass.find_by_code(self.member_code).nil?
      self.member_code = "TW-#{(0...size).map { charset.to_a[rand(charset.size)] }.join}"
    end
  end

  def source_order
    self.membership_line_item.order
  end

  def last_effective_date
    lp = self.membership_payments.max_by{|payment| payment.processed_on.to_date}
    if lp.nil?
      self.created_at.nil? ? Date.today : self.created_at.to_date
    else
      lp.processed_on + 1.month
    end
  end

  def recurring_order
    self.membership_order
  end

  private

  def release_reservations_on_cancel
    if self.status_changed? && self.canceled?
      cancel_future_reservations
    end
  end

  def release_pending_tasks_on_cancel
    if self.status_changed? && self.canceled?
      o = self.membership_line_item.order
      o.cancel_pending_tasks
      o.save!
    end
  end

  def cancel_future_reservations
    Membership.transaction do
      led = self.last_effective_date
      self.membership_payments.each do |payment|
        o = payment.order
        d = o.reservation_date
        unless d.nil? || d.to_datetime < led || o.refunded?
          o.refund!
        end
      end
    end
    true
  end

  def to_s
    "Membership #{member_code}"
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

  def last_payment
    membership_order.payments.sort{|p1,p2|p1.processed_on<=>p2.processed_on}.last
  end

end


