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
      raise Exceptions::TooManyTicketsForMembership.new("This membership only allows #{membership_offer.tickets_per_performance} seat#{'s' if membership_offer.tickets_per_performance > 1} per performance") if seats_covered_on(order) > membership_offer.tickets_per_performance

      verify_performance_total_for(order)
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

  # Seats on +order+ this membership pays for.
  # MembershipPaymentType#build_uncharged_payment records the order's ticket
  # count on the payment, so for an ordinary order
  # this is exactly number_of_seats. Seats paid another way and merged in
  # later (Add to Order) are not the membership's, so the covered count is
  # capped by the membership's own payments.
  def seats_covered_on(order)
    payments = order.membership_payments.select { |p| p.membership_id == id }
    return order.number_of_seats if payments.empty? || payments.any? { |p| p.number_of_tickets.nil? }

    [payments.sum(&:number_of_tickets), order.number_of_seats].min
  end

  # The cap holds across orders: this membership's tickets to the performance
  # on its other attending orders plus the ones this order redeems. Only
  # MembershipPayment rows count (Payment STI scopes match every type unless
  # pinned). Exchanged, canceled, refunded and merged orders no longer attend.
  # The order an exchange is replacing still reads PROCESSED while its
  # replacement saves, so it is exempt, as in ResourcedStockValidatable.
  #
  # Until 2026-09 the query's arguments were swapped (performance_id = order
  # id) and it compared only the other orders' total with the cap, so this
  # rule had never fired since 2011.
  def verify_performance_total_for(order)
    cap = membership_offer.tickets_per_performance
    requested = order.membership_payments.select { |p| p.membership_id == id }.sum { |p| p.number_of_tickets.to_i }
    return unless requested.positive?

    already = tickets_on_other_orders_for(order)
    return if already + requested <= cap

    raise Exceptions::TooManyTicketsForMembership.new(
      "This membership allows #{cap} seat#{'s' if cap > 1} per performance and #{already} " \
      "#{already == 1 ? 'is' : 'are'} already reserved on other orders; #{requested} more " \
      'is not allowed for this membership.'
    )
  end

  def tickets_on_other_orders_for(order)
    exempt_ids = [order.id, order.try(:exchange_source_id)].compact
    MembershipPayment.where(type: 'MembershipPayment', membership_id: id)
                     .joins(:order)
                     .where(orders: { performance_id: order.performance_id, status: Order::ATTENDING_STATUSES })
                     .where.not(order_id: exempt_ids)
                     .sum(:number_of_tickets)
  end

  # Timed ("library pass") rules: ONE redemption order per calendar week
  # (Monday-Sunday), for up to tickets_per_performance seats to a single
  # performance. Any prior attending redemption whose performance falls in the
  # same week -- even for the same performance -- blocks the order. Applies to
  # box office sales too; there is deliberately no box_office_sale bypass.
  def verify_timed_use_for(order)
    limit = membership_offer.tickets_per_performance
    raise Exceptions::TooManyTicketsForMembership.new("This pass only allows #{limit} seat#{'s' if limit > 1} per performance") if !limit.nil? && seats_covered_on(order) > limit

    return if order.membership_payments.sum { |li| li.number_of_tickets } == 0

    week_start = order.performance.performance_date.beginning_of_week(:monday)
    already_used = MembershipPayment.joins(order: :performance).exists?(
      ['payments.membership_id = :membership_id and orders.id != :order_id and
        orders.status in (:attending) and
        performances.performance_date between :week_start and :week_end',
       { membership_id: id,
         order_id: order.id || -1,
         attending: Order::ATTENDING_STATUSES,
         week_start: week_start,
         week_end: week_start + 6.days }]
    )

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

    week_start = Date.current.beginning_of_week(:monday)
    return if (week_start..(week_start + 6.days)).cover?(order.performance.performance_date.to_date)

    raise Exceptions::PerformanceOutsideCurrentWeek.new("This pass can only reserve performances through Sunday, #{(week_start + 6.days).strftime('%B %d')}. Reservations for later weeks open on the Monday of that week.")
  end

  # A one-time membership covers performances through its last day,
  # expires_on. Subscriptions have no expiry date and are not checked here.
  # Like verify_bookable_this_week!, called at redemption time only
  # (MembershipPayment#process!), not from verify_applicable_for: that re-runs
  # on any later save of a Processed order, which would start failing if
  # staff shortened expires_on after the booking.
  def verify_within_term_for!(order)
    return if expires_on.nil? || order.performance.nil?
    return if order.performance.performance_date.to_date <= expires_on

    raise Exceptions::MembershipExpiredForPerformance.new(
      "This membership expires on #{expires_on.to_formatted_s(:long)} and cannot be used for a performance after that date."
    )
  end

  # Bought with a one-time payment: it ends on expires_on rather than when a
  # Stripe subscription does.
  def one_time?
    expires_on.present?
  end

  # Ends a one-time membership at the close of its term. ended_at is the
  # expiry date, set explicitly so stamp_ended_at_on_close does not stamp the
  # day the job happens to run.
  def expire!
    self.ended_at = expires_on
    self.status = EXPIRED
    save!
  end

  def create_code(size = 6)
    charset = %w{2 3 4 6 7 9 A C D E F G H J K L M N P Q R T V W X Y Z}
    while member_code.nil? || !FlexPass.find_by_code(member_code).nil?
      self.member_code = "TW-#{(0...size).map { charset.to_a[rand(charset.size)] }.join}"
    end
  end

  # The year printed on a member ID card: when this patron first became a
  # member, across every membership on the address -- a lapsed-and-rejoined
  # patron keeps their original year. Pending memberships never activated, so
  # they do not count (same exclusion as MembershipOffer#usage_date_range).
  # Falls back to this membership's own dates when the address has none.
  def patron_member_since_year
    earliest = if address
                 address.memberships.where.not(status: PENDING)
                        .minimum(Arel.sql('COALESCE(memberships.start_date, memberships.member_since)'))
               end
    (earliest || start_date || member_since)&.to_date&.year
  end

  def source_order
    membership_line_item.order
  end

  # The last date reservations made with this membership stay valid when staff
  # cancel it. A timed (library) pass is free, so nothing is paid ahead and its
  # upcoming reservations end now. A one-time membership was paid through
  # expires_on; otherwise the last redemption plus a month (the assumed
  # billing period).
  def last_effective_date
    return Time.current if membership_offer&.timed?
    return expires_on if one_time?

    lp = membership_payments.max_by { |payment| payment.processed_on.to_date }
    if lp.nil?
      created_at.nil? ? Date.current : created_at.to_date
    else
      lp.processed_on + 1.month
    end
  end

  def recurring_order
    membership_order
  end

  # Months from the start (Stripe start, else member_since) to the end: today
  # while Active, otherwise ended_at. A partial month counts as a full one
  # (Jan 15 - Feb 8 is 1, Jan 15 - Feb 20 is 2), and an end before the start
  # is 0. Nil while there is no end date (e.g. Pending).
  # MembershipDatatable::DURATION_SQL sorts by the same rule.
  def duration_months
    starts_on = start_date || member_since
    ends_on = active? ? Date.current : ended_at
    return if starts_on.nil? || ends_on.nil?

    months = ((ends_on.year * 12) + ends_on.month) - ((starts_on.year * 12) + starts_on.month)
    months += 1 if ends_on.day > starts_on.day
    [months, 0].max
  end

  private

  # Stripe-managed memberships get ended_at from subscription sync
  # (RecurringProfile#update_from_profile); staff-closed memberships (admin
  # form, library passes) otherwise have no end date, which reporting needs.
  # The blank-guard keeps a Stripe-provided date authoritative.
  def stamp_ended_at_on_close
    self.ended_at = Date.current if status_changed? && [CANCELED, EXPIRED].include?(status) && ended_at.blank?
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
  # The actual add/remove HTTP work happens in SyncMembershipMyEmmaJob,
  # which decides from the membership's state at run time.
  after_save :enqueue_myemma_list_sync, :if => :status_changed_for_myemma?

  def status_changed_for_myemma?
    saved_change_to_status? && !MyEmma.disabled?
  end

  def enqueue_myemma_list_sync
    Resque.enqueue(SyncMembershipMyEmmaJob, id)
  end

  def last_payment
    membership_order.payments.sort { |p1, p2| p1.processed_on <=> p2.processed_on }.last
  end
end
