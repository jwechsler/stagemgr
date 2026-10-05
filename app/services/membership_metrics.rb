# Shared definitions behind the membership numbers on the Membership Usage
# report and the Membership Analysis page, so both read a membership's window
# and its money the same way.
#
# Payments are the evidence a membership ran: status and ended_at on
# PayPal-era records often disagree with them (paying memberships left
# Pending, payments long after ended_at), so the window follows the money.
#
# Window: a membership runs from COALESCE(start_date, member_since) through
# its effective end (open when NULL).
#
# Started: a membership counts once it is past Pending, or once it has been
# paid at all. Pending with no payments never activated and is excluded.
#
# Effective end: open for an Active membership with no ended_at. Otherwise the
# later of ended_at and its paid-through date: the last positive payment on
# its membership order plus one of the offer's billing periods (a month when
# no period has been synced from Stripe).
# With neither, the window closes at its start. So a Suspended or Pending
# membership that stopped paying counts only through the months it paid for.
module MembershipMetrics
  # Days in an average month, for turning day counts into months.
  AVERAGE_DAYS_PER_MONTH = BigDecimal('30.44')

  WINDOW_START_SQL = 'COALESCE(memberships.start_date, memberships.member_since)'.freeze

  # One billing period of the membership's offer, split into the months and
  # days to add to a payment date (MembershipOffer#billing_period_for in SQL):
  # years and months are calendar months, a one-time price lasts the gift
  # length or a year, weeks and days are days, and no synced period is a
  # month.
  PERIOD_MONTHS_SQL = <<~SQL.squish.freeze
    (SELECT CASE period_offers.billing_interval
              WHEN '#{MembershipOffer::YEAR}' THEN 12 * COALESCE(period_offers.billing_interval_count, 1)
              WHEN '#{MembershipOffer::MONTH}' THEN COALESCE(period_offers.billing_interval_count, 1)
              WHEN '#{MembershipOffer::ONE_TIME}'
                THEN COALESCE(period_offers.max_cycles_if_gift, #{MembershipOffer::DEFAULT_ONE_TIME_MONTHS})
              WHEN '#{MembershipOffer::WEEK}' THEN 0
              WHEN '#{MembershipOffer::DAY}' THEN 0
              ELSE 1
            END
       FROM membership_offers period_offers
      WHERE period_offers.id = memberships.membership_offer_id)
  SQL

  PERIOD_DAYS_SQL = <<~SQL.squish.freeze
    (SELECT CASE period_offers.billing_interval
              WHEN '#{MembershipOffer::WEEK}' THEN 7 * COALESCE(period_offers.billing_interval_count, 1)
              WHEN '#{MembershipOffer::DAY}' THEN COALESCE(period_offers.billing_interval_count, 1)
              ELSE 0
            END
       FROM membership_offers period_offers
      WHERE period_offers.id = memberships.membership_offer_id)
  SQL

  # Refunds (negative) and $0 trial payments do not extend a membership.
  PAID_THROUGH_SQL = <<~SQL.squish.freeze
    ((SELECT DATE(MAX(paid_through_payments.processed_on))
        FROM line_items paid_through_items
        INNER JOIN payments paid_through_payments ON paid_through_payments.order_id = paid_through_items.order_id
       WHERE paid_through_items.type = 'MembershipLineItem'
         AND paid_through_items.membership_id = memberships.id
         AND paid_through_payments.amount > 0)
      + INTERVAL #{PERIOD_MONTHS_SQL} MONTH + INTERVAL #{PERIOD_DAYS_SQL} DAY)
  SQL

  STARTED_SQL = <<~SQL.squish.freeze
    (memberships.status <> '#{Membership::PENDING}' OR #{PAID_THROUGH_SQL} IS NOT NULL)
  SQL

  EFFECTIVE_END_SQL = <<~SQL.squish.freeze
    CASE WHEN memberships.status = '#{Membership::ACTIVE}' AND memberships.ended_at IS NULL THEN NULL
         ELSE GREATEST(COALESCE(memberships.ended_at, #{WINDOW_START_SQL}),
                       COALESCE(#{PAID_THROUGH_SQL}, #{WINDOW_START_SQL}))
    END
  SQL

  PAYMENT_WINDOW_SQL = 'payments.processed_on >= :from AND payments.processed_on < :to_exclusive'.freeze

  module_function

  # Memberships whose window overlaps [from, to] (both dates inclusive).
  def overlapping(scope, from, to)
    scope.where(STARTED_SQL)
         .where("#{WINDOW_START_SQL} <= :to AND (#{EFFECTIVE_END_SQL} IS NULL OR #{EFFECTIVE_END_SQL} >= :from)",
                from: from, to: to)
  end

  # Memberships whose window covers +date+.
  def active_on(scope, date)
    overlapping(scope, date, date)
  end

  # Membership redemptions (MembershipPayment rows) processed in
  # [from, to_exclusive). The STI type is pinned explicitly: Payment.descendants
  # is overridden (app/models/payments/payment.rb) in a way that makes
  # MembershipPayment scopes match every loaded payment type.
  def paid_payments(from, to_exclusive)
    MembershipPayment.where(type: MembershipPayment.sti_name)
                     .where(PAYMENT_WINDOW_SQL, from: from, to_exclusive: to_exclusive)
  end

  # Money taken on membership purchase orders in [from, to_exclusive),
  # anchored on the membership and traversed out to its order's payments, so
  # memberships without an order (staff-issued library passes) contribute
  # nothing. Refunds are negative payments and net out.
  def collected_payments(from, to_exclusive)
    membership_order_payments.where(PAYMENT_WINDOW_SQL, from: from, to_exclusive: to_exclusive)
  end

  # Memberships joined to every payment on their membership purchase order,
  # with no date bound.
  def membership_order_payments
    Membership.joins(membership_line_item: { membership_order: :payments })
  end

  # Days of [coverage_start, coverage_end) that fall inside
  # [span_start, span_end); all four are day numbers (Date#jd) with
  # exclusive ends. Never negative.
  def overlap_days(coverage_start, coverage_end, span_start, span_end)
    [[coverage_end, span_end].min - [coverage_start, span_start].max, 0].max
  end

  # Exchange offsets of membership redemptions processed in
  # [from, to_exclusive). An exchange offsets the original MembershipPayment
  # with a negative ExchangePayment (TicketOrder#begin_exchange!) rather than a
  # negative MembershipPayment, so paid_payments alone counts an exchanged
  # redemption twice. Attributed through the source payment, whose
  # membership_id is always set (the offset's own membership_id is not).
  # Older exchanges wrote negative MembershipPayment rows instead, which
  # paid_payments already nets.
  def redemption_exchange_offsets(from, to_exclusive)
    ExchangePayment.where(type: ExchangePayment.sti_name)
                   .joins('INNER JOIN payments source_payments ON source_payments.id = payments.payment_id')
                   .where(source_payments: { type: MembershipPayment.sti_name })
                   .where(PAYMENT_WINDOW_SQL, from: from, to_exclusive: to_exclusive)
  end

  # redemption_exchange_offsets joined to the redeemed membership and its
  # offer (through the source payment), for reports that group by offer.
  def redemption_exchange_offsets_with_offers(from, to_exclusive)
    redemption_exchange_offsets(from, to_exclusive)
      .joins('INNER JOIN memberships ON memberships.id = source_payments.membership_id')
      .joins('INNER JOIN membership_offers ON membership_offers.id = memberships.membership_offer_id')
  end
end
