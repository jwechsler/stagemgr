# Membership economics over a date range for a set of offers: a Total row
# across the selected offers plus one row per offer. Membership windows and
# money follow the Membership Usage report's rules (MembershipMetrics).
#
#   MembershipAnalysis.new(offer_ids, starting_date, ending_date).compute
#
# Both dates are inclusive. "Active at end" means active on ending_date, not
# today. Per-membership economics are monthly rates over the membership's
# active span in the range: each payment's rate is its amount over the months
# it pays for (MembershipOffer#billing_months), covering the calendar period
# Stripe billed (MembershipOffer#billing_period_for), and revenue per month is
# those rates averaged over the span's days. Total averages, minimums and
# maximums pool every membership of the selected offers; they are never
# averages of the per-offer figures.
class MembershipAnalysis
  # by_offer holds only offers with activity in the range; idle_offers are the
  # selected offers that had none (listed by name, not as empty rows).
  Result = Struct.new(:total, :by_offer, :idle_offers, keyword_init: true)

  OfferStats = Struct.new(
    :offer, :memberships_in_range, :memberships_active_at_end,
    :members_in_range, :members_active_at_end,
    :collected, :redeemed_orders, :redeemed_amount,
    :new_count, :dropped_count, :avg_length_days,
    :economics_per_month,
    keyword_init: true
  ) do
    def net
      collected - redeemed_amount
    end

    # Any membership in the range, or any money collected or redeemed in it.
    def activity?
      memberships_in_range.positive? || !collected.zero? || !redeemed_amount.zero? || redeemed_orders.positive?
    end
  end

  # One per-membership figure (revenue, redeemed or net) across a set of
  # memberships. minimum_membership / maximum_membership are MembershipRefs.
  Spread = Struct.new(:avg, :minimum, :maximum, :minimum_membership, :maximum_membership, keyword_init: true)
  Economics = Struct.new(:membership_count, :revenue, :redeemed, :net, keyword_init: true)
  MembershipRef = Struct.new(:id, :member_code, keyword_init: true)

  # Internal: one plucked membership with its in-range money. Memberships in
  # range also carry their active span in it (both dates inclusive) and
  # rate_days: the monthly rate of each payment covering the span, times the
  # days of the span it covers, summed.
  Row = Struct.new(:id, :offer_id, :member_code, :window_start, :effective_end, :status, :member_count,
                   :in_range, :active_at_end, :revenue, :redeemed, :span_start, :span_end, :rate_days,
                   keyword_init: true) do
    # Months actually active in the span. Revenue is already spread across
    # the period each payment covers, so dividing by the real time gives the
    # rate even for a member who joined days before the range end.
    def active_months
      span_days / MembershipMetrics::AVERAGE_DAYS_PER_MONTH
    end

    def span_days
      (span_end - span_start).to_i + 1
    end

    # Redemptions are not spread, so a short span divides by at least one
    # month to keep one early redemption from reading as a huge monthly rate.
    def redemption_months
      [active_months, 1].max
    end

    def revenue_per_month
      rate_days / span_days
    end

    def redeemed_per_month
      redeemed / redemption_months
    end

    def net_per_month
      revenue_per_month - redeemed_per_month
    end
  end

  # Offer-picker group resolved when the analysis runs, against the dates
  # chosen then: every offer (active or not) with a membership active at some
  # point in the range.
  WITH_ACTIVE_MEMBERSHIPS = 'with_active_memberships'.freeze
  DYNAMIC_GROUPS = [WITH_ACTIVE_MEMBERSHIPS].freeze

  # Ids from +offers+ (a MembershipOffer relation) matched by the dynamic
  # +groups+ over [starting_date, ending_date]. Unknown keys match nothing.
  def self.offer_ids_for_groups(groups, offers, starting_date, ending_date)
    return [] unless Array(groups).include?(WITH_ACTIVE_MEMBERSHIPS)

    MembershipMetrics.overlapping(Membership.where(membership_offer_id: offers.select(:id)),
                                  starting_date.to_date, ending_date.to_date)
                     .distinct.pluck(:membership_offer_id)
  end

  attr_reader :offer_ids, :starting_date, :ending_date

  def initialize(offer_ids, starting_date, ending_date)
    @offer_ids = Array(offer_ids).compact_blank.map(&:to_i)
    @starting_date = starting_date.to_date
    @ending_date = ending_date.to_date
  end

  def compute
    rows = membership_rows
    order_offers = redeemed_order_offers
    sorted_offers = offers.values.sort_by { |offer| [offer.active? ? 0 : 1, offer.name.to_s] }

    by_offer = sorted_offers.map do |offer|
      stats_for(offer, rows.select { |row| row.offer_id == offer.id },
                order_offers.select { |_order_id, offer_id| offer_id == offer.id })
    end
    active, idle = by_offer.partition(&:activity?)
    Result.new(total: stats_for(nil, rows, order_offers), by_offer: active, idle_offers: idle.map(&:offer))
  end

  private

  # Payments are bounded by processed_on < the day after the end date.
  def payments_end
    ending_date + 1.day
  end

  def offers
    @offers ||= MembershipOffer.where(id: offer_ids).index_by(&:id)
  end

  def offer_memberships
    Membership.joins(:membership_offer).where(membership_offer_id: offer_ids)
  end

  def membership_ids_subquery
    Membership.where(membership_offer_id: offer_ids).select(:id)
  end

  def membership_rows
    in_range = MembershipMetrics.overlapping(offer_memberships, starting_date, ending_date).pluck(:id).to_set
    active_at_end = MembershipMetrics.active_on(offer_memberships, ending_date).pluck(:id).to_set
    collected = collected_by_membership
    redeemed = redeemed_by_membership

    rows = offer_memberships.pluck(*membership_columns).map do |id, offer_id, code, start, effective_end, status, members|
      Row.new(id: id, offer_id: offer_id, member_code: code, window_start: start&.to_date,
              effective_end: effective_end&.to_date, status: status, member_count: members.to_i,
              in_range: in_range.include?(id), active_at_end: active_at_end.include?(id),
              revenue: collected.fetch(id, 0).to_d, redeemed: redeemed.fetch(id, 0).to_d)
    end
    with_spans(rows)
  end

  # Gives each membership in range its active span in the range and the share
  # of its payments, from any date, that falls inside that span.
  def with_spans(rows)
    in_range = rows.select(&:in_range)
    payments = payments_by_membership(in_range.map(&:id))
    in_range.each do |row|
      row.span_start = [row.window_start, starting_date].max
      row.span_end = [row.effective_end || ending_date, ending_date].min
      row.rate_days = rate_days(row, payments.fetch(row.id, []))
    end
    rows
  end

  # [amount, processed_on date] per membership, for every payment on its
  # membership order: a payment before the range can pay for months inside it.
  def payments_by_membership(membership_ids)
    MembershipMetrics.membership_order_payments
                     .where(id: membership_ids)
                     .where.not(payments: { processed_on: nil })
                     .pluck('memberships.id', 'payments.amount', 'payments.processed_on')
                     .group_by(&:first)
                     .transform_values { |payments| payments.map { |_id, amount, paid| [amount.to_d, paid.to_date] } }
  end

  # Revenue per month is the time-weighted average of the monthly rates
  # paying for the span: each payment's rate (amount / months it pays for)
  # times the span days it covers. Days nothing paid for count as $0. A
  # refund is placed by the date it was issued, so it carries a negative rate
  # over the billing period it was issued in, not the period of the charge it
  # reverses: a credit-back or partial refund lowers the month it happened.
  def rate_days(row, payments)
    span = [row.span_start.jd, row.span_end.jd + 1]
    payments.sum(0.to_d) do |amount, paid_on|
      start, finish, months = coverage(row, paid_on)
      next 0.to_d unless months.positive?

      amount / months * MembershipMetrics.overlap_days(start.jd, finish.jd, *span)
    end
  end

  # [start, end) dates a payment pays for, and how many months that is.
  def coverage(row, paid_on)
    offer = offers[row.offer_id]
    period = offer.billing_period_for(paid_on, anchor_day: row.window_start.day)
    return one_time_coverage(row) if period.nil?

    [*period, offer.billing_months]
  end

  # From the window start through the effective end, or, while the membership
  # is open, through the offer's intended length.
  def one_time_coverage(row)
    return [row.window_start, row.effective_end + 1.day, length_in_months(row)] if row.effective_end

    months = offers[row.offer_id].max_cycles_if_gift || MembershipOffer::DEFAULT_ONE_TIME_MONTHS
    [row.window_start, row.window_start >> months, months]
  end

  def length_in_months(row)
    ((row.effective_end + 1.day) - row.window_start).to_i / MembershipMetrics::AVERAGE_DAYS_PER_MONTH
  end

  def membership_columns
    ['memberships.id', 'memberships.membership_offer_id', 'memberships.member_code',
     Arel.sql(MembershipMetrics::WINDOW_START_SQL), Arel.sql(MembershipMetrics::EFFECTIVE_END_SQL),
     'memberships.status', 'membership_offers.tickets_per_performance']
  end

  def collected_by_membership
    MembershipMetrics.collected_payments(starting_date, payments_end)
                     .where(membership_offer_id: offer_ids)
                     .reorder(nil).group('memberships.id').sum('payments.amount')
  end

  # Net redemptions per membership: MembershipPayment rows (refunds and older
  # exchanges are negative MembershipPayments) plus current exchange offsets.
  def redeemed_by_membership
    paid = MembershipMetrics.paid_payments(starting_date, payments_end)
                            .where(membership_id: membership_ids_subquery)
                            .reorder(nil).group(:membership_id).sum(:amount)
    offsets = MembershipMetrics.redemption_exchange_offsets(starting_date, payments_end)
                               .where(source_payments: { membership_id: membership_ids_subquery })
                               .reorder(nil).group('source_payments.membership_id').sum('payments.amount')
    paid.merge(offsets) { |_id, paid_amount, offset_amount| paid_amount + offset_amount }
  end

  # [order_id, offer_id] pairs for finalized orders (Processed, Fulfilled or
  # Unclaimed) with a membership redemption processed in range: the same
  # orders whose redemptions make up $ redeemed. A no-show (Unclaimed) still
  # used the membership. Exchanged and refunded orders are not finalized, so
  # an exchange counts only its replacement order.
  def redeemed_order_offers
    MembershipMetrics.paid_payments(starting_date, payments_end)
                     .joins(:order, :membership)
                     .where(orders: { status: Order::FINALIZED_STATUSES })
                     .where(memberships: { membership_offer_id: offer_ids })
                     .reorder(nil)
                     .distinct
                     .pluck('payments.order_id', 'memberships.membership_offer_id')
  end

  def stats_for(offer, rows, order_offers)
    in_range = rows.select(&:in_range)
    active_at_end = rows.select(&:active_at_end)
    ended = ended_in_range(rows)
    started = new_in_range(rows)

    OfferStats.new(
      offer: offer,
      memberships_in_range: in_range.size, memberships_active_at_end: active_at_end.size,
      members_in_range: in_range.sum(&:member_count), members_active_at_end: active_at_end.sum(&:member_count),
      collected: rows.sum(0.to_d, &:revenue), redeemed_amount: rows.sum(0.to_d, &:redeemed),
      redeemed_orders: order_offers.map(&:first).uniq.size,
      new_count: started.size, dropped_count: ended.size,
      avg_length_days: average((ended | active_at_end).map { |row| length_days(row) }),
      economics_per_month: economics(in_range)
    )
  end

  # Memberships that began in the range. in_range already excludes
  # memberships that never started (Pending and never paid).
  def new_in_range(rows)
    rows.select { |row| row.in_range && row.window_start >= starting_date }
  end

  # Whole length of a membership, from its start: to its end when it ended in
  # the range, or to the end of the range when it is still running then.
  def length_days(row)
    finish = row.active_at_end ? ending_date : row.effective_end
    (finish - row.window_start).to_i
  end

  # Memberships that ran in the range but had ended by its end: their
  # effective end (see MembershipMetrics) falls inside it.
  def ended_in_range(rows)
    rows.select { |row| row.in_range && !row.active_at_end && row.effective_end }
  end

  def economics(rows)
    Economics.new(membership_count: rows.size, revenue: spread(rows, &:revenue_per_month),
                  redeemed: spread(rows, &:redeemed_per_month), net: spread(rows, &:net_per_month))
  end

  def spread(rows, &value)
    return Spread.new if rows.empty?

    min_row = rows.min_by(&value)
    max_row = rows.max_by(&value)
    Spread.new(avg: average(rows.map(&value)), minimum: value.call(min_row), maximum: value.call(max_row),
               minimum_membership: ref(min_row), maximum_membership: ref(max_row))
  end

  def ref(row)
    MembershipRef.new(id: row.id, member_code: row.member_code)
  end

  def average(values)
    return nil if values.empty?

    values.sum.to_d / values.size
  end
end
