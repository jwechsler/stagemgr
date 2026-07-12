class MembershipUsageReport < Report
  ALL_OFFERS_LABEL = 'All Offers'.freeze
  MONTH_KEY = "DATE_FORMAT(payments.processed_on, '%Y-%m')".freeze
  MEMBERS_SQL = 'SUM(membership_offers.tickets_per_performance)'.freeze

  attr_reader :starting_date, :ending_date, :membership_offer_ids

  # membership_offer_ids accepts a single id or an array of ids; empty
  # means no offer restriction.
  def initialize(starting_date, ending_date, reporting_user_id = nil, membership_offer_ids = nil)
    super(%i[Month Offer Memberships Members Collected Paid], reporting_user_id)
    @starting_date = starting_date.to_date
    # @ending_date is the exclusive upper bound (payments.processed_on < @ending_date).
    # Cap it at the first of the current month so the current, still-incomplete
    # month is never reported — its payment data isn't final yet.
    @ending_date = [ending_date.to_date + 1.day, Date.current.beginning_of_month].min
    @membership_offer_ids = Array(membership_offer_ids).compact
    @data = []
  end

  def create
    ActiveRecord::Base.connection.execute("SET sql_mode=(SELECT REPLACE(@@sql_mode, 'ONLY_FULL_GROUP_BY', ''));")

    monthly = monthly_totals
    by_offer = offer_breakouts

    ActiveRecord::Base.connection.execute("SET sql_mode=CONCAT(@@sql_mode, ',ONLY_FULL_GROUP_BY');")

    detail_rows = []
    months(monthly).each do |month|
      offer_names_for(month, by_offer).each do |offer|
        row = offer_row(month, offer, by_offer)
        detail_rows << row
        data << row
      end
      data << summary_row(month, monthly) unless suppress_monthly_subtotals?
    end

    data << total_row(detail_rows) if detail_rows.any?

    unless reporting_user_id.nil?
      return report_data("/tmp/membership_usage_report_#{starting_date.to_date.strftime('%y%m%d')}_#{ending_date.to_date.strftime('%y%m%d')}.csv")
    end

    report_data
  end

  private

  # Every metric is anchored on the Membership record: Memberships counts
  # active-in-month memberships directly, and the payment columns traverse
  # from the membership out to its payments. Purchase orders whose membership
  # record no longer exists are therefore invisible here — the report is
  # about memberships, not orders. When scoped to offers, the monthly totals
  # apply the same offer restriction so the summary rows match the breakouts.
  def monthly_totals
    memberships, members = active_membership_metrics
    {
      paid: (offers_selected? ? paid_by_offer : paid_scope).group(MONTH_KEY).sum('payments.amount'),
      collected: (offers_selected? ? collected_by_offer : collected_scope).group(MONTH_KEY).sum('payments.amount'),
      memberships: memberships,
      members: members
    }
  end

  def offer_breakouts
    memberships, members = active_membership_metrics(by_offer: true)
    {
      paid: paid_by_offer.group(MONTH_KEY, 'membership_offers.name').sum('payments.amount'),
      collected: collected_by_offer.group(MONTH_KEY, 'membership_offers.name').sum('payments.amount'),
      memberships: memberships,
      members: members
    }
  end

  def paid_by_offer
    only_selected_offers(paid_scope.joins(membership: :membership_offer))
  end

  def collected_by_offer
    only_selected_offers(collected_scope.joins(:membership_offer))
  end

  def only_selected_offers(relation)
    offers_selected? ? relation.where(membership_offers: { id: membership_offer_ids }) : relation
  end

  def offers_selected?
    membership_offer_ids.present?
  end

  def single_offer?
    membership_offer_ids.length == 1
  end

  # Omit the per-month "All Offers" subtotal rows when scoped to a single offer
  # (they duplicate that offer's row) and on CSV downloads (reporting_user_id is
  # set), where the interleaved subtotals add noise to the exported detail data.
  # With several offers selected the subtotal aggregates just those offers, so
  # it stays.
  def suppress_monthly_subtotals?
    single_offer? || reporting_user_id.present?
  end

  def paid_scope
    # Pin the STI type explicitly: Payment.descendants is overridden
    # (app/models/payments/payment.rb) in a way that makes MembershipPayment
    # scopes match every loaded payment type, which historically inflated the
    # Paid totals with non-membership payments.
    MembershipPayment.where(type: MembershipPayment.sti_name).where(
      'payments.processed_on >= :starting_date AND payments.processed_on < :ending_date',
      starting_date: starting_date, ending_date: ending_date
    )
  end

  # Collected is a payments fact: money taken on membership purchase orders,
  # attributed to the month it was processed. Anchored on the membership and
  # traversed out to its order's payments so memberships without an order
  # (staff-issued library passes) simply contribute nothing.
  def collected_scope
    Membership.joins(membership_line_item: { membership_order: :payments }).where(
      'payments.processed_on >= :starting_date AND payments.processed_on < :ending_date',
      starting_date: starting_date, ending_date: ending_date
    )
  end

  # Memberships is a membership fact, not a billing fact: a membership counts
  # in every month that overlaps its active window, regardless of whether a
  # payment landed that month (trials, comps, failed charges, order-less
  # library passes). Window: COALESCE(start_date, member_since) through
  # ended_at (open when NULL); currently-Pending memberships never activated
  # and are excluded. Suspended is a transient billing state and still counts.
  #
  # Members counts people rather than memberships: each membership admits
  # tickets_per_performance patrons (a dual membership is two members).
  # Returns [memberships, members] hashes sharing the memberships keying.
  def active_membership_metrics(by_offer: false)
    memberships = {}
    members = {}
    report_months.each do |month_start|
      scope = active_memberships_in(month_start)
      month_key = month_start.strftime('%Y-%m')
      if by_offer
        scope.group('membership_offers.name')
             .pluck('membership_offers.name', Arel.sql('COUNT(*)'), Arel.sql(MEMBERS_SQL))
             .each do |offer_name, count, member_count|
          memberships[[month_key, offer_name]] = count
          members[[month_key, offer_name]] = member_count
        end
      else
        count, member_count = scope.pick(Arel.sql('COUNT(*)'), Arel.sql(MEMBERS_SQL))
        next unless count.positive?

        memberships[month_key] = count
        members[month_key] = member_count
      end
    end
    [memberships, members]
  end

  def active_memberships_in(month_start)
    scope = Membership.joins(:membership_offer)
                      .where.not(status: Membership::PENDING)
                      .where(
                        'COALESCE(memberships.start_date, memberships.member_since) <= :month_end AND
                          (memberships.ended_at IS NULL OR memberships.ended_at >= :month_start)',
                        month_start: month_start, month_end: month_start.end_of_month
                      )
    only_selected_offers(scope)
  end

  def report_months
    month = starting_date.beginning_of_month
    last = (ending_date - 1.day).beginning_of_month
    months = []
    while month <= last
      months << month
      month += 1.month
    end
    months
  end

  def months(monthly)
    monthly.values.flat_map(&:keys).uniq.sort
  end

  def offer_names_for(month, by_offer)
    by_offer.values.flat_map(&:keys).select { |m, _offer| m == month }.map(&:last).uniq.sort
  end

  def offer_row(month, offer, by_offer)
    key = [month, offer]
    { Month: month, Offer: offer,
      Memberships: by_offer[:memberships][key] || 0,
      Members: by_offer[:members][key] || 0,
      Collected: (by_offer[:collected][key] || 0).to_money,
      Paid: (by_offer[:paid][key] || 0).to_money,
      display_class: :report_detail_row }
  end

  def summary_row(month, monthly)
    { Month: month, Offer: ALL_OFFERS_LABEL,
      Memberships: monthly[:memberships][month] || 0,
      Members: monthly[:members][month] || 0,
      Collected: (monthly[:collected][month] || 0).to_money,
      Paid: (monthly[:paid][month] || 0).to_money,
      display_class: :report_summary_row }
  end

  # Grand total of the detail (per-offer) rows across every month. Memberships
  # and Members are left blank: they're active-during-month counts, so summing
  # them across months double-counts every membership that spans more than one
  # month.
  def total_row(detail_rows)
    { Month: 'Total', Offer: '',
      Memberships: '', Members: '',
      Collected: detail_rows.sum(0.to_money) { |row| row[:Collected] },
      Paid: detail_rows.sum(0.to_money) { |row| row[:Paid] },
      display_class: :report_summary_row }
  end
end
