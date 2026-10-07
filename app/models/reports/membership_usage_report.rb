class MembershipUsageReport < Report
  ALL_OFFERS_LABEL = 'All Offers'.freeze
  MONTH_KEY = "DATE_FORMAT(payments.processed_on, '%Y-%m')".freeze
  MEMBERS_SQL = 'SUM(membership_offers.tickets_per_performance)'.freeze
  HEADERS = [:Month, :Offer, :Memberships, :Members, :Collected, :Paid, :Passes, :'Pass Redeemed'].freeze

  attr_reader :starting_date, :ending_date, :membership_offer_ids

  # membership_offer_ids accepts a single id or an array of ids; empty
  # means no offer restriction.
  def initialize(starting_date, ending_date, reporting_user_id = nil, membership_offer_ids = nil)
    super(HEADERS.dup, reporting_user_id)
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
  #
  # Timed offers (library passes) are reported apart from memberships: they
  # fill Passes and Pass Redeemed, never Memberships, Members or Paid. Paid is
  # every redemption less the passes' (rather than production redemptions
  # alone) so it keeps counting redemptions whose membership record is gone.
  def monthly_totals
    pass_redeemed = paid_sums(MONTH_KEY, timed_only: true)
    monthly_membership_metrics.merge(
      paid: paid_sums(MONTH_KEY).to_h { |month, paid| [month, paid - pass_redeemed.fetch(month, 0)] },
      collected: (offers_selected? ? collected_by_offer : collected_scope).group(MONTH_KEY).sum('payments.amount'),
      pass_redeemed: pass_redeemed
    )
  end

  def offer_breakouts
    memberships, members = offer_membership_metrics
    {
      paid: paid_sums(MONTH_KEY, 'membership_offers.name', by_offer: true),
      collected: collected_by_offer.group(MONTH_KEY, 'membership_offers.name').sum('payments.amount'),
      memberships: memberships,
      members: members
    }
  end

  # Paid nets exchange offsets: an exchange offsets the original redemption
  # with a negative ExchangePayment rather than a negative MembershipPayment
  # (see MembershipMetrics.redemption_exchange_offsets), so without them an
  # exchanged redemption would count on both the original and the
  # replacement order. Offsets land in the month they were processed.
  # timed_only limits the sums to timed offers (Pass Redeemed).
  def paid_sums(*group_columns, by_offer: false, timed_only: false)
    joined = by_offer || timed_only || offers_selected?
    redemptions = joined ? paid_by_offer : paid_scope
    offsets = MembershipMetrics.redemption_exchange_offsets_with_offers(starting_date, ending_date)
    offsets = only_selected_offers(offsets) if joined
    redemptions, offsets = [redemptions, offsets].map { |scope| only_timed(scope) } if timed_only
    redemptions.reorder(nil).group(*group_columns).sum('payments.amount')
               .merge(offsets.reorder(nil).group(*group_columns).sum('payments.amount')) { |_key, paid, offset| paid + offset }
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

  def only_timed(relation)
    relation.where(membership_offers: { membership_type: MembershipOffer::TIMED })
  end

  def timed_offer_names
    @timed_offer_names ||= MembershipOffer.where(membership_type: MembershipOffer::TIMED).pluck(:name).to_set
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
    MembershipMetrics.paid_payments(starting_date, ending_date)
  end

  # Collected is a payments fact: money taken on membership purchase orders,
  # attributed to the month it was processed (see MembershipMetrics).
  def collected_scope
    MembershipMetrics.collected_payments(starting_date, ending_date)
  end

  # Memberships is a membership fact, not a billing fact: a membership counts
  # in every month that overlaps its active window, regardless of whether a
  # payment landed that month (trials, comps, failed charges, order-less
  # library passes). The window is MembershipMetrics': it starts at
  # COALESCE(start_date, member_since) and stays open for an Active membership
  # with no ended_at; otherwise it runs to the later of ended_at and the
  # paid-through date (last payment + 1 month), so payments win over stale
  # status and end dates. A Pending membership that never paid is excluded.
  #
  # Members counts people rather than memberships: each membership admits
  # tickets_per_performance patrons (a dual membership is two members).
  # Returns [memberships, members] hashes keyed by [month, offer name]. For a
  # timed offer the memberships count is its Passes: one per pass, however
  # many seats it admits.
  def offer_membership_metrics
    memberships = {}
    members = {}
    report_months.each do |month_start|
      month_key = month_start.strftime('%Y-%m')
      active_memberships_in(month_start)
        .group('membership_offers.name')
        .pluck('membership_offers.name', Arel.sql('COUNT(*)'), Arel.sql(MEMBERS_SQL))
        .each do |offer_name, count, member_count|
          memberships[[month_key, offer_name]] = count
          members[[month_key, offer_name]] = member_count
        end
    end
    [memberships, members]
  end

  # The same counts per month across offers, with timed passes split out:
  # { memberships:, members:, passes: }, each keyed by month.
  def monthly_membership_metrics
    metrics = { memberships: {}, members: {}, passes: {} }
    report_months.each do |month_start|
      month_key = month_start.strftime('%Y-%m')
      active_memberships_in(month_start)
        .group('membership_offers.membership_type')
        .pluck('membership_offers.membership_type', Arel.sql('COUNT(*)'), Arel.sql(MEMBERS_SQL))
        .each do |type, count, member_count|
          if type == MembershipOffer::TIMED
            metrics[:passes][month_key] = count
          else
            metrics[:memberships][month_key] = (metrics[:memberships][month_key] || 0) + count
            metrics[:members][month_key] = (metrics[:members][month_key] || 0) + member_count
          end
        end
    end
    metrics
  end

  def active_memberships_in(month_start)
    scope = MembershipMetrics.overlapping(Membership.joins(:membership_offer), month_start, month_start.end_of_month)
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

  # A production offer fills the membership columns and leaves the pass
  # columns blank; a timed offer the reverse.
  def offer_row(month, offer, by_offer)
    key = [month, offer]
    row = { Month: month, Offer: offer, Memberships: '', Members: '', Collected: '', Paid: '',
            Passes: '', 'Pass Redeemed': '', display_class: :report_detail_row }
    if timed_offer_names.include?(offer)
      row.merge(Passes: by_offer[:memberships][key] || 0, 'Pass Redeemed': (by_offer[:paid][key] || 0).to_money)
    else
      row.merge(Memberships: by_offer[:memberships][key] || 0,
                Members: by_offer[:members][key] || 0,
                Collected: (by_offer[:collected][key] || 0).to_money,
                Paid: (by_offer[:paid][key] || 0).to_money)
    end
  end

  def summary_row(month, monthly)
    { Month: month, Offer: ALL_OFFERS_LABEL,
      Memberships: monthly[:memberships][month] || 0,
      Members: monthly[:members][month] || 0,
      Collected: (monthly[:collected][month] || 0).to_money,
      Paid: (monthly[:paid][month] || 0).to_money,
      Passes: monthly[:passes][month] || 0,
      'Pass Redeemed': (monthly[:pass_redeemed][month] || 0).to_money,
      display_class: :report_summary_row }
  end

  # Grand total of the detail (per-offer) rows across every month.
  # Memberships, Members and Passes are left blank: they're active-during-month
  # counts, so summing them across months double-counts every membership or
  # pass that spans more than one month.
  def total_row(detail_rows)
    { Month: 'Total', Offer: '',
      Memberships: '', Members: '',
      Collected: money_total(detail_rows, :Collected),
      Paid: money_total(detail_rows, :Paid),
      Passes: '',
      'Pass Redeemed': money_total(detail_rows, :'Pass Redeemed'),
      display_class: :report_summary_row }
  end

  # Sum of a money column, skipping the rows where it is blank.
  def money_total(rows, column)
    rows.sum(0.to_money) { |row| row[column].presence || 0.to_money }
  end
end
