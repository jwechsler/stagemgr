class FlexPassUsageReport < Report
  attr_reader :starting_date, :ending_date, :flex_pass_offer_ids

  # flex_pass_offer_ids accepts a single id or an array of ids; empty
  # means no offer restriction.
  def initialize(starting_date, ending_date, flex_pass_offer_ids = nil, reporting_user_id = nil)
    super(%i[month new_passes new_deposits tickets_redeemed tickets_paid_out
             total_spiff total_flat_payout total_facility expired_flex_passes
             recovered_amount total_due_to_facility], reporting_user_id)
    @starting_date = starting_date
    @ending_date = ending_date
    @flex_pass_offer_ids = Array(flex_pass_offer_ids).compact
    @data = []
  end

  def create
    ActiveRecord::Base.connection.execute("SET sql_mode=(SELECT REPLACE(@@sql_mode, 'ONLY_FULL_GROUP_BY', ''));")

    pass_payments = FlexPassPayment.where('processed_on >= :start and processed_on <= :end',
                                          start: starting_date, end: ending_date)
    if flex_pass_offer_ids.present?
      pass_payments = pass_payments.joins(flex_pass: :flex_pass_offer).where(
        flex_passes: { flex_pass_offer_id: flex_pass_offer_ids }
      )
    end
    # Redemption counts and paid-out dollars diverge for zero-dollar passes
    # (e.g. producer subscriptions): every use has a ticket count, but the
    # payment amount is 0 when the offer carries no price or payout.
    tickets_redeemed = pass_payments.group("DATE_FORMAT(processed_on, '%Y-%m')")
                                    .reorder(:processed_on)
                                    .sum('number_of_tickets').to_h
    paid_amount = pass_payments.group("DATE_FORMAT(processed_on, '%Y-%m')")
                               .reorder(:processed_on)
                               .sum('amount').to_h
    paid_amount = (paid_amount.keys + tickets_redeemed.keys).uniq.index_with do |key|
      { tickets_paid_out: paid_amount[key] || 0.0, tickets_redeemed: tickets_redeemed[key] || 0 }
    end

    # Deposits come straight from each order's payments; pass counts and
    # per-pass offer amounts are summed one row per pass and bucketed by
    # the month of the order's first in-range payment. The old single
    # query joined passes and payments together, multiplying deposits by
    # the order's pass count (legacy line items carry several passes) and
    # pass counts by its payment count.
    sold_orders = FlexPassOrder.all
    if flex_pass_offer_ids.present?
      sold_orders = sold_orders.where(id: FlexPassOrder.joins(flex_pass_line_item: :flex_pass)
                                                       .where(flex_passes: { flex_pass_offer_id: flex_pass_offer_ids })
                                                       .select(:id))
    end
    paying_orders = sold_orders.joins(:payments)
                               .where('payments.processed_on >= :starting_date AND payments.processed_on <= :ending_date',
                                      starting_date: starting_date, ending_date: ending_date)

    monthly_deposits = paying_orders.group("DATE_FORMAT(payments.processed_on, '%Y-%m')").sum('payments.amount')
    order_payment_months = paying_orders.group('orders.id').minimum('payments.processed_on')
                                        .transform_values { |processed_on| processed_on.strftime('%Y-%m') }

    pass_scope = FlexPass.joins(:flex_pass_offer)
                         .joins(flex_pass_line_item: :flex_pass_order)
                         .where(line_items: { order_id: paying_orders.select('orders.id') })
    pass_scope = pass_scope.where(flex_pass_offer_id: flex_pass_offer_ids) if flex_pass_offer_ids.present?
    per_order_passes = pass_scope.group('line_items.order_id')
                                 .pluck(Arel.sql('line_items.order_id'), Arel.sql('COUNT(*)'),
                                        Arel.sql('SUM(COALESCE(flex_pass_offers.spiff, 0))'),
                                        Arel.sql('SUM(COALESCE(flex_pass_offers.flat_payout, 0))'),
                                        Arel.sql('SUM(COALESCE(flex_pass_offers.facility_fee, 0))'))

    # Every pass expiring in range counts — including never-redeemed passes,
    # which are fully recovered — and each pass's price and fees count
    # exactly once. Redemption payouts are summed in a separate query:
    # joining payments alongside the price sum used to multiply each pass's
    # price by its number of redemptions.
    expiring_passes = FlexPass.joins(:flex_pass_offer)
                              .where('expiration_date >= :starting_date AND expiration_date <= :ending_date',
                                     starting_date: starting_date, ending_date: ending_date)
    if flex_pass_offer_ids.present?
      expiring_passes = expiring_passes.where(flex_pass_offer_id: flex_pass_offer_ids)
    end

    expiration_month = "DATE_FORMAT(expiration_date, '%Y-%m')"
    expired_counts = expiring_passes.group(expiration_month).count
    gross_recoverable = expiring_passes.group(expiration_month).sum(
      'flex_pass_offers.price - COALESCE(flex_pass_offers.facility_fee, 0) - COALESCE(flex_pass_offers.flat_payout, 0)'
    )
    paid_out_on_expiring = expiring_passes.joins(:flex_pass_payments)
                                          .group(expiration_month)
                                          .sum('payments.amount')

    recovered_amounts_hash = expired_counts.keys.index_with do |month|
      { expired_flex_passes: expired_counts[month],
        recovered_amount: gross_recoverable[month] - (paid_out_on_expiring[month] || 0) }
    end

    collected_amounts_hash = {}
    per_order_passes.each do |order_id, pass_count, spiff, flat_payout, facility|
      month = order_payment_months[order_id]
      next unless month

      bucket = collected_amounts_hash[month] ||= empty_collected_bucket
      bucket[:new_passes] += pass_count
      bucket[:total_spiff] += spiff
      bucket[:total_flat_payout] += flat_payout
      bucket[:total_facility] += facility
    end
    monthly_deposits.each do |month, amount|
      bucket = collected_amounts_hash[month] ||= empty_collected_bucket
      bucket[:new_deposits] = amount
    end

    months = (paid_amount.keys + recovered_amounts_hash.keys + collected_amounts_hash.keys).uniq.sort

    months.each do |month|
      merged_hash = (paid_amount[month] || {}).merge(recovered_amounts_hash[month] || {}).merge(collected_amounts_hash[month] || {})

      data << { month: month,
                new_passes: merged_hash[:new_passes] || 0,
                new_deposits: (merged_hash[:new_deposits] || 0.0).to_money,
                tickets_redeemed: merged_hash[:tickets_redeemed] || 0,
                tickets_paid_out: (merged_hash[:tickets_paid_out] || 0.0).to_money,
                total_spiff: (merged_hash[:total_spiff] || 0.0).to_money,
                total_flat_payout: (merged_hash[:total_flat_payout] || 0.0).to_money,
                total_facility: (merged_hash[:total_facility] || 0.0).to_money,
                expired_flex_passes: merged_hash[:expired_flex_passes] || 0,
                recovered_amount: (merged_hash[:recovered_amount] || 0.0).to_money,
                total_due_to_facility: ((merged_hash[:total_spiff] || 0.0) + (merged_hash[:total_facility] || 0.0) + (merged_hash[:recovered_amount] || 0.0)).to_money }
    end
    filename = "_#{starting_date.to_date.strftime('%y%m%d')}_#{ending_date.to_date.strftime('%y%m%d')}.csv"
    if flex_pass_offer_ids.length == 1
      offer = FlexPassOffer.find(flex_pass_offer_ids.first)
      filename = "#{Admin::ReportsHelper.safe_title(offer.name)}_usage_#{filename}"
    else
      filename = "flex_pass_usage_#{filename}"
    end
    report_data(filename)
  end

  private

  def empty_collected_bucket
    { new_passes: 0, new_deposits: 0, total_spiff: 0, total_flat_payout: 0, total_facility: 0 }
  end
end
