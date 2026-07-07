class MembershipUsageReport < Report
  ALL_OFFERS_LABEL = 'All Offers'.freeze
  MONTH_KEY = "DATE_FORMAT(payments.processed_on, '%Y-%m')".freeze

  attr_reader :starting_date, :ending_date, :membership_offer_ids

  # membership_offer_ids accepts a single id or an array of ids; empty
  # means no offer restriction.
  def initialize(starting_date, ending_date, reporting_user_id = nil, membership_offer_ids = nil)
    super(%i[Month Offer Memberships Collected Paid], reporting_user_id)
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

  # Aggregate monthly totals are queried independently of the per-offer breakouts so the
  # summary rows keep the historical behavior even for records that cannot be
  # joined to a membership offer (e.g. legacy rows missing a membership).
  # When scoped to a single offer, the monthly totals join that offer too so the
  # summary row reflects only that offer.
  def monthly_totals
    {
      paid: (offers_selected? ? paid_by_offer : paid_scope).group(MONTH_KEY).sum('payments.amount'),
      collected: (offers_selected? ? collected_by_offer : collected_scope).group(MONTH_KEY).sum('payments.amount'),
      memberships: (offers_selected? ? memberships_by_offer : membership_count_scope)
                   .distinct.group(MONTH_KEY).count('line_items.membership_id')
    }
  end

  def offer_breakouts
    {
      paid: paid_by_offer.group(MONTH_KEY, 'membership_offers.name').sum('payments.amount'),
      collected: collected_by_offer.group(MONTH_KEY, 'membership_offers.name').sum('payments.amount'),
      memberships: memberships_by_offer.distinct
                                       .group(MONTH_KEY, 'membership_offers.name').count('line_items.membership_id')
    }
  end

  def paid_by_offer
    only_selected_offers(paid_scope.joins(membership: :membership_offer))
  end

  def collected_by_offer
    only_selected_offers(collected_scope.joins(membership_line_item: :membership_offer))
  end

  def memberships_by_offer
    only_selected_offers(membership_count_scope.joins(:membership_offer))
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

  # Grand total of the detail (per-offer) rows across every month.
  def total_row(detail_rows)
    { Month: 'Total', Offer: '',
      Memberships: detail_rows.sum { |row| row[:Memberships] },
      Collected: detail_rows.sum(0.to_money) { |row| row[:Collected] },
      Paid: detail_rows.sum(0.to_money) { |row| row[:Paid] },
      display_class: :report_summary_row }
  end
end
