class MembershipUsageReport < Report
  ALL_OFFERS_LABEL = 'All Offers'.freeze
  MONTH_KEY = "DATE_FORMAT(payments.processed_on, '%Y-%m')".freeze

  attr_reader :starting_date, :ending_date

  def initialize(starting_date, ending_date, reporting_user_id = nil)
    super(%i[Month Offer Memberships Collected Paid], reporting_user_id)
    @starting_date = starting_date.to_date
    @ending_date = ending_date.to_date + 1.day
    @data = []
  end

  def create
    ActiveRecord::Base.connection.execute("SET sql_mode=(SELECT REPLACE(@@sql_mode, 'ONLY_FULL_GROUP_BY', ''));")

    monthly = monthly_totals
    by_offer = offer_breakouts

    ActiveRecord::Base.connection.execute("SET sql_mode=CONCAT(@@sql_mode, ',ONLY_FULL_GROUP_BY');")

    months(monthly).each do |month|
      offer_names_for(month, by_offer).each do |offer|
        data << offer_row(month, offer, by_offer)
      end
      data << summary_row(month, monthly)
    end

    unless reporting_user_id.nil?
      return report_data("/tmp/membership_usage_report_#{starting_date.to_date.strftime('%y%m%d')}_#{ending_date.to_date.strftime('%y%m%d')}.csv")
    end

    report_data
  end

  private

  # Aggregate monthly totals are queried independently of the per-offer breakouts so the
  # summary rows keep the historical behavior even for records that cannot be
  # joined to a membership offer (e.g. legacy rows missing a membership).
  def monthly_totals
    {
      paid: paid_scope.group(MONTH_KEY).sum('payments.amount'),
      collected: collected_scope.group(MONTH_KEY).sum('payments.amount'),
      memberships: membership_count_scope.distinct.group(MONTH_KEY).count('line_items.membership_id')
    }
  end

  def offer_breakouts
    {
      paid: paid_scope.joins(membership: :membership_offer)
                      .group(MONTH_KEY, 'membership_offers.name').sum('payments.amount'),
      collected: collected_scope.joins(membership_line_item: :membership_offer)
                                .group(MONTH_KEY, 'membership_offers.name').sum('payments.amount'),
      memberships: membership_count_scope.joins(:membership_offer).distinct
                                         .group(MONTH_KEY, 'membership_offers.name').count('line_items.membership_id')
    }
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

  def collected_scope
    MembershipOrder.joins(:payments).where(
      'payments.processed_on >= :starting_date AND payments.processed_on < :ending_date',
      starting_date: starting_date, ending_date: ending_date
    )
  end

  def membership_count_scope
    MembershipLineItem.joins(membership_order: :payments).where(
      'payments.processed_on >= :starting_date AND payments.processed_on < :ending_date',
      starting_date: starting_date, ending_date: ending_date
    )
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
      Collected: (by_offer[:collected][key] || 0).to_money,
      Paid: (by_offer[:paid][key] || 0).to_money,
      display_class: :report_detail_row }
  end

  def summary_row(month, monthly)
    { Month: month, Offer: ALL_OFFERS_LABEL,
      Memberships: monthly[:memberships][month] || 0,
      Collected: (monthly[:collected][month] || 0).to_money,
      Paid: (monthly[:paid][month] || 0).to_money,
      display_class: :report_summary_row }
  end
end
