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
  before_save :stamp_ended_at_on_close
  before_save :release_reservations_on_cancel
  before_save :release_pending_tasks_on_cancel

  def verify_applicable_for(order)
    return verify_timed_use_for(order) if membership_offer.timed?

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

    festival_id = order.performance.production.festival_id
    cap = membership_offer.max_festival_tickets_in_advance
    if festival_id.present? && !cap.nil? && !order.box_office_sale
      requested = order.membership_payments.sum { |li| li.number_of_tickets }
      if requested > 0
        already = MembershipPayment.joins(order: { performance: :production }).where(
          'payments.membership_id = :membership_id and orders.id != :order_id and
            productions.festival_id = :festival_id and orders.status in (:attending)',
          membership_id: id,
          order_id: order.id,
          festival_id: festival_id,
          attending: Order::ATTENDING_STATUSES
        ).sum(:number_of_tickets)
        if (already + requested) > cap
          festival = order.performance.production.festival
          raise Exceptions::FestivalTicketsAtDoorOnly.new("This membership covers #{cap} #{festival.name} ticket#{'s' if cap > 1} in advance. Additional festival tickets are available at the box office on the day of each performance.")
        end
      end
    end
  end

  # Timed ("library pass") rules: ONE redemption order per calendar week
  # (Monday-Sunday), for up to tickets_per_performance seats to a single
  # performance. Any prior attending redemption whose performance falls in the
  # same week -- even for the same performance -- blocks the order. Applies to
  # box office sales too; there is deliberately no box_office_sale bypass.
  def verify_timed_use_for(order)
    limit = membership_offer.tickets_per_performance
    raise Exceptions::TooManyTicketsForMembership.new("This pass only allows #{limit} seat#{'s' if limit > 1} per performance") if !limit.nil? && order.number_of_seats > limit

    return if order.membership_payments.sum { |li| li.number_of_tickets } == 0

    week_start = order.performance.performance_date.beginning_of_week(:monday)
    already_used = MembershipPayment.joins(order: :performance).where(
      'payments.membership_id = :membership_id and orders.id != :order_id and
        orders.status in (:attending) and
        performances.performance_date between :week_start and :week_end',
      membership_id: id,
      order_id: order.id || -1,
      attending: Order::ATTENDING_STATUSES,
      week_start: week_start,
      week_end: week_start + 6.days
    ).exists?

    raise Exceptions::PassAlreadyUsedThisWeek.new("This pass has already been used this week. It can be used again starting Monday, #{(week_start + 7.days).strftime('%B %d')}.") if already_used
  end

  # Booking-window rule for timed passes: redemption may only target a
  # performance in the CURRENT calendar week. Called from
  # MembershipPayment#process! at redemption time only -- NOT from
  # verify_applicable_for, because Order#validate_membership_payments re-runs
  # that on any later save of a Processed order, which would spuriously fail
  # once the week has passed.
  def verify_bookable_this_week!(order)
    return unless membership_offer.timed?

    week_start = Date.today.beginning_of_week(:monday)
    return if (week_start..week_start + 6.days).cover?(order.performance.performance_date.to_date)

    raise Exceptions::PerformanceOutsideCurrentWeek.new("This pass can only reserve performances through Sunday, #{(week_start + 6.days).strftime('%B %d')}. Reservations for later weeks open on the Monday of that week.")
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

  # Stripe-managed memberships get ended_at from subscription sync
  # (RecurringProfile#update_from_profile); staff-closed memberships (admin
  # form, library passes) otherwise have no end date, which reporting needs.
  # The blank-guard keeps a Stripe-provided date authoritative.
  def stamp_ended_at_on_close
    self.ended_at = Date.today if status_changed? && [CANCELED, EXPIRED].include?(status) && ended_at.blank?
  end

  def release_reservations_on_cancel
    if status_changed? && canceled?
      cancel_future_reservations
    end
  end

  def release_pending_tasks_on_cancel
    if status_changed? && canceled?
      o = membership_line_item&.order
      return true if o.nil?

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
