class Membership < ApplicationRecord
  include RecurringProfile

  SEATING_REQUESTS = (
    BEST_AVAILABLE, FRONT_ROW, TOWARDS_REAR, ON_AISLE, WHEELCHAIR, STAIRS =
      'Best available (center)', 'Front row', 'Towards rear', 'On aisle', 'Wheelchair', 'No stairs')

  has_one :membership_line_item, :foreign_key => :membership_id
  has_one :membership_order, :through => :membership_line_item
  has_many :special_offers, :dependent => :destroy, inverse_of: :membership
  belongs_to :membership_offer
  belongs_to :address, inverse_of: :memberships
  has_many :membership_payments, inverse_of: :membership

  before_destroy :cancel_future_reservations
  validates_presence_of :membership_offer
  before_validation :create_code, :on => :create
  before_save :release_reservations_on_cancel
  before_save :release_pending_tasks_on_cancel

  def verify_applicable_for(order)
    unless membership_offer.tickets_per_performance.nil?
      perfs = Order.where(
        "performance_id = ? and id <> ? and id in (select order_id from payments where type = 'MembershipPayment' and membership_id = ?)", order.id, order.performance_id, id
      )

      raise Exceptions::TooManyTicketsForMembership.new("This membership only allows #{membership_offer.tickets_per_performance} seat#{'s' if membership_offer.tickets_per_performance > 1} per performance") if order.number_of_seats > membership_offer.tickets_per_performance
      raise Exceptions::TooManyTicketsForMembership.new("This membership allows you #{membership_offer.tickets_per_performance} seat#{'s' if membership_offer.tickets_per_performance > 1} per production") if membership_offer.tickets_per_performance < perfs.inject(0) { |sum, o1| sum + o1.membership_payments.inject(0) { |sum, p| sum + p.number_of_tickets } }
    end
    if order.membership_payments.sum { |li| li.number_of_tickets } > 0
      prod_count = Performance.includes(
        orders: [[ticket_line_items: :ticket_class], :payments]
      ).references(:orders, :payments, :ticket_classes).where(
        'payments.type = \'MembershipPayment\' and payments.membership_id = :membership_id and
          orders.id != :order_id and performances.production_id = :production_id and
          ticket_classes.class_code = :class_code and orders.status in (:attending)',
        class_code: membership_offer.use_ticket_class_code,
        membership_id: id,
        order_id: order.id,
        production_id: order.performance.production_id,
        attending: Order::ATTENDING_STATUSES
      ).count
      raise Exceptions::RepeatVisitsAtDoorOnly.new("Tickets for repeat trips to the same show are based on availability at the door on the day of performance.  To see this show again, just come to the box office with your member pass on #{order.performance.performance_date.strftime("%B %d")} at #{(order.performance.performance_time - 30.minutes).strftime("%I:%M%p")}.") if prod_count > 0
    end
  end

  def create_code(size = 6)
    charset = %w{2 3 4 6 7 9 A C D E F G H J K L M N P Q R T V W X Y Z}
    while member_code.nil? || !FlexPass.find_by_code(member_code).nil?
      self.member_code = "TW-#{(0...size).map { charset.to_a[rand(charset.size)] }.join}"
    end
  end

  def source_order
    membership_line_item.order
  end

  def last_effective_date
    lp = membership_payments.max_by { |payment| payment.processed_on.to_date }
    if lp.nil?
      created_at.nil? ? Date.today : created_at.to_date
    else
      lp.processed_on + 1.month
    end
  end

  def recurring_order
    membership_order
  end

  private

  def release_reservations_on_cancel
    if status_changed? && canceled?
      cancel_future_reservations
    end
  end

  def release_pending_tasks_on_cancel
    if status_changed? && canceled?
      o = membership_line_item.order
      o.cancel_pending_tasks
      o.save!
    end
  end

  def cancel_future_reservations
    Membership.transaction do
      led = last_effective_date
      membership_payments.each do |payment|
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
    (status_changed? || saved_change_to_status?) && !MyEmma.disabled?
  end

  def update_my_emma_membership
    if status_changed?
      if inactive?
        remove_from_membership_list
      else
        add_to_membership_list
      end
    end
  end

  def add_to_membership_list
    unless membership_offer.myemma_group.nil?
      begin
        member = MyEmma::Member.new
        member.name_first = address.first_name
        member.name_last = address.last_name
        member.email = address.email
        member.address = address.line1
        member.city = address.city
        member.state = address.state
        member.postal_code = address.zipcode
        member.save([membership_offer.myemma_group])
      rescue Exception => e
        Rails.logger.error("Could not update membership mailing list for address ##{address.id}, #{e.message}")
      end
    end
  end

  def remove_from_membership_list
    group_id = membership_offer.myemma_group
    unless group_id.blank? || address.email.blank? || address.is_current_member?
      begin
        member = MyEmma::Member.find_by_email(address.email)

        unless member.nil?
          group = MyEmma::Group.find(group_id)
          group.remove_members(member)
        end
      rescue Exception => e
        Rails.logger.error("Could not update membership mailing list for address ##{address.id}, #{e.message}")
      end
    end
  end

  def update_membership_list_subscription
    if inactive?
      remove_from_membership_list
    else
      add_to_membership_list
    end
    true
  end

  def last_payment
    membership_order.payments.sort { |p1, p2| p1.processed_on <=> p2.processed_on }.last
  end
end
