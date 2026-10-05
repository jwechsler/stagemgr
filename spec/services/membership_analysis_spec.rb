require 'rails_helper'

RSpec.describe MembershipAnalysis do
  let(:range_start) { Date.new(2026, 1, 1) }
  let(:range_end) { Date.new(2026, 6, 30) }
  let(:in_range) { Time.zone.local(2026, 3, 10, 12, 0, 0) }

  let(:gold_offer) { FactoryBot.create(:membership_offer, name: 'Gold', tickets_per_performance: 2) }
  let(:silver_offer) do
    FactoryBot.create(:membership_offer, name: 'Silver', tickets_per_performance: 1, status: MembershipOffer::INACTIVE)
  end

  def analyze(offers = [gold_offer, silver_offer], from: range_start, to: range_end)
    described_class.new(offers.map(&:id), from, to).compute
  end

  def stats_for(result, offer)
    result.by_offer.find { |stats| stats.offer.id == offer.id }
  end

  # A membership bought through a membership order. +collected+ is a list of
  # [amount, processed_on] payments on that order.
  def membership_with_order(offer, code:, collected: [], member_since: Date.new(2026, 1, 15),
                            ended_at: nil, status: Membership::ACTIVE)
    order = FactoryBot.create(:membership_order)
    order.membership_line_item.update!(membership_offer: offer)
    membership = order.membership
    membership.update!(membership_offer: offer, member_code: code, member_since: member_since,
                       ended_at: ended_at, status: status)
    order.payments.each(&:destroy!)
    collected.each do |amount, processed_on|
      FactoryBot.create(:cash_payment, order: order, amount: amount, processed_on: processed_on)
    end
    membership
  end

  def membership_without_order(offer, code:, member_since: Date.new(2026, 1, 15), ended_at: nil,
                               status: Membership::ACTIVE)
    FactoryBot.create(:membership, membership_offer: offer, member_code: code, member_since: member_since,
                                   ended_at: ended_at, status: status)
  end

  def set_billing_period(offer, interval, count = 1)
    offer.update_columns(billing_interval: interval, billing_interval_count: count,
                         billing_period_synced_at: Time.current)
  end

  def redeem(membership, amount, processed_on, status: Order::PROCESSED)
    ticket_order = FactoryBot.create(:ticket_order)
    ticket_order.update_column(:status, status)
    payment = FactoryBot.create(:membership_payment, order: ticket_order, membership: membership,
                                                     number_of_tickets: 1, amount: amount,
                                                     processed_on: processed_on)
    [ticket_order, payment]
  end

  describe 'memberships and members' do
    it 'counts a dual membership as two members' do
      membership_without_order(gold_offer, code: 'GOLD1')
      membership_without_order(silver_offer, code: 'SILV1')

      result = analyze

      expect(stats_for(result, gold_offer)).to have_attributes(memberships_in_range: 1, members_in_range: 2)
      expect(stats_for(result, silver_offer)).to have_attributes(memberships_in_range: 1, members_in_range: 1)
      expect(result.total).to have_attributes(memberships_in_range: 2, members_in_range: 3,
                                              memberships_active_at_end: 2, members_active_at_end: 3)
    end

    it 'excludes Pending memberships' do
      membership_without_order(gold_offer, code: 'PEND1', status: Membership::PENDING)

      expect(analyze.total).to have_attributes(memberships_in_range: 0, memberships_active_at_end: 0)
    end

    it 'judges "active at end" on the end date, not today' do
      membership_without_order(gold_offer, code: 'LATE1', ended_at: Date.new(2026, 8, 1),
                                           status: Membership::CANCELED)
      membership_without_order(gold_offer, code: 'EARLY1', ended_at: Date.new(2026, 5, 1),
                                           status: Membership::CANCELED)

      expect(analyze.total).to have_attributes(memberships_in_range: 2, memberships_active_at_end: 1)
    end

    it 'includes inactive offers, listed after the active ones' do
      membership_without_order(gold_offer, code: 'GOLD1')
      membership_without_order(silver_offer, code: 'SILV1')

      result = analyze

      expect(result.by_offer.map(&:offer)).to eq([gold_offer, silver_offer])
      expect(stats_for(result, silver_offer).memberships_in_range).to eq(1)
    end

    it 'leaves offers with no activity in the range out of the rows and lists them as idle' do
      membership_without_order(silver_offer, code: 'SILV2', member_since: Date.new(2024, 1, 1),
                                             ended_at: Date.new(2024, 12, 31), status: Membership::CANCELED)
      membership_without_order(gold_offer, code: 'GOLD2')

      result = analyze

      expect(result.by_offer.map(&:offer)).to eq([gold_offer])
      expect(result.idle_offers).to eq([silver_offer])
    end

    it 'keeps an offer whose only activity in the range is money' do
      pending_member = membership_without_order(silver_offer, code: 'SILV3', status: Membership::PENDING)
      redeem(pending_member, 20, in_range)

      expect(analyze.by_offer.map(&:offer)).to eq([silver_offer])
    end

    it 'returns zeros for an empty selection' do
      result = described_class.new([], range_start, range_end).compute

      expect(result.by_offer).to be_empty
      expect(result.total).to have_attributes(memberships_in_range: 0, collected: 0, redeemed_amount: 0,
                                              redeemed_orders: 0, new_count: 0, dropped_count: 0,
                                              avg_length_days: nil)
      expect(result.total.economics_per_month).to have_attributes(membership_count: 0)
      expect(result.total.economics_per_month.revenue.avg).to be_nil
    end
  end

  describe 'money' do
    it 'counts a membership that started before the range, but only its in-range payments' do
      membership = membership_with_order(gold_offer, code: 'OLD1', member_since: Date.new(2025, 6, 1),
                                                     collected: [[50, Time.zone.local(2025, 12, 15, 12)],
                                                                 [50, Time.zone.local(2026, 2, 15, 12)]])
      redeem(membership, 10, Time.zone.local(2025, 12, 20, 12))
      redeem(membership, 20, in_range)

      gold = stats_for(analyze, gold_offer)

      expect(gold).to have_attributes(memberships_in_range: 1, collected: 50, redeemed_amount: 20,
                                      redeemed_orders: 1)
    end

    it 'counts a payment on the end date itself' do
      membership = membership_without_order(gold_offer, code: 'END1')
      redeem(membership, 15, Time.zone.local(2026, 6, 30, 12))

      expect(analyze.total.redeemed_amount).to eq(15)
    end

    it 'nets exchange offsets out of $ redeemed and counts only the replacement order' do
      membership = membership_without_order(gold_offer, code: 'EXCH1')
      original_order, original_payment = redeem(membership, 20, in_range, status: Order::EXCHANGED)
      ExchangePayment.create!(order: original_order, amount: -20, payment_id: original_payment.id,
                              payment_type: original_payment.payment_type, processed_on: in_range + 1.day)
      redeem(membership, 20, in_range + 1.day)

      expect(analyze.total).to have_attributes(redeemed_amount: 20, redeemed_orders: 1)
    end

    it 'nets an older-style negative MembershipPayment exchange offset' do
      membership = membership_without_order(gold_offer, code: 'EXCH2')
      original_order, = redeem(membership, 20, in_range, status: Order::EXCHANGED)
      FactoryBot.create(:membership_payment, order: original_order, membership: membership, number_of_tickets: -1,
                                             amount: -20, processed_on: in_range + 1.day)
      redeem(membership, 25, in_range + 1.day)

      expect(analyze.total).to have_attributes(redeemed_amount: 25, redeemed_orders: 1)
    end

    it 'counts an unclaimed (no-show) order, matching its redeemed amount' do
      membership = membership_without_order(gold_offer, code: 'NOSHOW1')
      redeem(membership, 20, in_range, status: Order::UNCLAIMED)

      expect(analyze.total).to have_attributes(redeemed_amount: 20, redeemed_orders: 1)
    end

    it 'does not count a refunded order' do
      membership = membership_without_order(gold_offer, code: 'REF1')
      refunded_order, = redeem(membership, 20, in_range, status: Order::REFUNDED)
      FactoryBot.create(:membership_payment, order: refunded_order, membership: membership, number_of_tickets: -1,
                                             amount: -20, processed_on: in_range + 1.day)

      expect(analyze.total).to have_attributes(redeemed_amount: 0, redeemed_orders: 0)
    end

    it 'never counts non-membership payments as redeemed' do
      membership_with_order(gold_offer, code: 'CC1', collected: [[80, in_range]])

      expect(analyze.total).to have_attributes(collected: 80, redeemed_amount: 0)
    end
  end

  describe 'per-membership economics, per month' do
    def months(days)
      BigDecimal(days) / MembershipMetrics::AVERAGE_DAYS_PER_MONTH
    end

    def about(value)
      a_value_within(0.0001).of(value)
    end

    def gold_economics(**range)
      stats_for(analyze(**range), gold_offer).economics_per_month
    end

    it 'gives $35/month for monthly $35 payments across the whole range' do
      payments = (1..12).map { |month| [35, Time.zone.local(2026, month, 1, 12)] }
      membership_with_order(gold_offer, code: 'MONTHLY', member_since: Date.new(2025, 12, 1), collected: payments)

      revenue = gold_economics(to: Date.new(2026, 12, 31)).revenue

      expect(revenue.avg).to be_within(0.1).of(35)
    end

    it 'gives exactly the monthly price when billed on the 30th, through a short February' do
      paid = %w[2025-12-30 2026-01-30 2026-02-28 2026-03-30 2026-04-30 2026-05-30 2026-06-30]
      membership_with_order(gold_offer, code: 'ON30TH', member_since: Date.new(2025, 11, 30),
                                        collected: paid.map { |day| [29, Time.zone.parse("#{day} 12:00")] })

      expect(gold_economics.revenue.avg).to eq(29)
    end

    it 'gives exactly the monthly price when a charge is retried days late' do
      paid = %w[2025-12-09 2026-01-13 2026-02-09 2026-03-09 2026-04-09 2026-05-09 2026-06-09]
      membership_with_order(gold_offer, code: 'RETRIED', member_since: Date.new(2025, 11, 9),
                                        collected: paid.map { |day| [29, Time.zone.parse("#{day} 12:00")] })

      expect(gold_economics.revenue.avg).to eq(29)
    end

    it 'spreads an annual payment made before the range across the months inside it' do
      set_billing_period(gold_offer, MembershipOffer::YEAR)
      membership_with_order(gold_offer, code: 'ANNUAL', member_since: Date.new(2025, 7, 1),
                                        collected: [[420, Time.zone.local(2025, 7, 1, 12)]])

      expect(gold_economics.revenue.avg).to be_within(0.01).of(35)
    end

    it 'spreads a one-time price across the whole membership, not just the range' do
      set_billing_period(gold_offer, MembershipOffer::ONE_TIME)
      gold_offer.update_column(:max_cycles_if_gift, nil)
      membership_with_order(gold_offer, code: 'ONCE', member_since: Date.new(2026, 1, 1),
                                        collected: [[120, Time.zone.local(2026, 1, 1, 12)]])

      # Twelve months from the start, though the range covers only two.
      expect(gold_economics(to: Date.new(2026, 2, 28)).revenue.avg).to be_within(0.01).of(10)
    end

    it "spreads a one-time price across the offer's gift length when it has one" do
      set_billing_period(gold_offer, MembershipOffer::ONE_TIME)
      gold_offer.update_column(:max_cycles_if_gift, 6)
      membership_with_order(gold_offer, code: 'GIFT', member_since: Date.new(2026, 1, 1),
                                        collected: [[60, Time.zone.local(2026, 1, 1, 12)]])

      expect(gold_economics(to: Date.new(2026, 2, 28)).revenue.avg).to be_within(0.1).of(10)
    end

    it 'shows a member who joined days before the range end at their full monthly rate' do
      membership_with_order(gold_offer, code: 'NEW', member_since: Date.new(2026, 6, 21),
                                        collected: [[35, Time.zone.local(2026, 6, 21, 12)]])

      # Ten days in range (June 21-30): ten days of the $35 over ten days of membership.
      expect(gold_economics.revenue.avg).to be_within(0.01).of(35)
    end

    it 'divides redemptions for a membership active under a month by one month' do
      membership = membership_without_order(gold_offer, code: 'SHORT', member_since: Date.new(2026, 3, 1),
                                                        ended_at: Date.new(2026, 3, 3), status: Membership::CANCELED)
      redeem(membership, 20, Time.zone.local(2026, 3, 2, 12))

      expect(gold_economics.redeemed.avg).to eq(20)
    end

    it 'lets a refund offset the payment it refunds' do
      membership_with_order(gold_offer, code: 'REFUND', member_since: Date.new(2025, 12, 1),
                                        collected: [[35, Time.zone.local(2026, 2, 1, 12)],
                                                    [-35, Time.zone.local(2026, 2, 5, 12)]])

      expect(gold_economics.revenue.avg).to eq(0)
    end

    it 'counts a refund in the billing period it was issued in, not that of the charge it reverses' do
      monthly = (1..6).map { |month| [50, Time.zone.local(2026, month, 1, 12)] }
      membership_with_order(gold_offer, code: 'CREDIT', member_since: Date.new(2025, 12, 1),
                                        collected: monthly + [[-20, Time.zone.local(2026, 2, 10, 12)]])

      # Issued Feb 10, so -$20/month over February's 28 days (not January's 31) of the 181-day span.
      expect(gold_economics.revenue.avg).to be_within(0.0001).of(50 - (BigDecimal(20) * 28 / 181))
    end

    it 'treats an offer with no price_id as monthly' do
      silver_offer.update_column(:price_id, nil)
      membership_with_order(silver_offer, code: 'NOPRICE', member_since: Date.new(2025, 12, 1),
                                          collected: [[30.44, Time.zone.local(2026, 6, 15, 12)]])

      # Billed on the 1st (its start day), so the June 15 payment pays for June 1 - July 1:
      # a $30.44 monthly rate over 30 of the span's 181 days.
      revenue = stats_for(analyze, silver_offer).economics_per_month.revenue

      expect(revenue.avg).to be_within(0.0001).of(BigDecimal('30.44') * 30 / 181)
    end

    context 'with several memberships' do
      let!(:big) { membership_with_order(gold_offer, code: 'BIG', collected: [[100, in_range]]) }
      let!(:heavy_user) { membership_with_order(gold_offer, code: 'HEAVY', collected: [[50, in_range]]) }
      let!(:silver) { membership_with_order(silver_offer, code: 'SILV', collected: [[40, in_range]]) }
      # Each runs from its start on 2026-01-15 to the range end: 167 days. Billed on the
      # 15th, its March 10 payment pays for Feb 15 - Mar 15: 28 of those days.
      let(:span) { months(167) }

      def rate(amount)
        BigDecimal(amount) * 28 / 167
      end

      before do
        redeem(big, 30, in_range)
        redeem(heavy_user, 80, in_range)
      end

      it 'reports avg, min and max per offer with the member codes behind the extremes' do
        economics = gold_economics

        expect(economics.membership_count).to eq(2)
        expect(economics.revenue).to have_attributes(avg: about(rate(75)), minimum: about(rate(50)),
                                                     maximum: about(rate(100)))
        expect(economics.revenue.minimum_membership).to have_attributes(id: heavy_user.id, member_code: 'HEAVY')
        expect(economics.revenue.maximum_membership).to have_attributes(id: big.id, member_code: 'BIG')
        expect(economics.redeemed).to have_attributes(avg: about(55 / span), minimum: about(30 / span),
                                                      maximum: about(80 / span))
        expect(economics.net).to have_attributes(avg: about(rate(75) - (55 / span)),
                                                 minimum: about(rate(50) - (80 / span)),
                                                 maximum: about(rate(100) - (30 / span)))
        expect(economics.net.minimum_membership.member_code).to eq('HEAVY')
      end

      it 'pools the total across memberships rather than averaging the offer averages' do
        total = analyze.total.economics_per_month

        expect(total.membership_count).to eq(3)
        expect(total.revenue.avg).to be_within(0.0001).of(rate(190) / 3)
        expect(total.revenue.minimum_membership.member_code).to eq('SILV')
        expect(total.net.maximum_membership.member_code).to eq('BIG')
      end
    end
  end

  describe 'new, dropped and average length' do
    before do
      membership_without_order(gold_offer, code: 'LONG', member_since: Date.new(2025, 1, 1),
                                           ended_at: Date.new(2026, 3, 1), status: Membership::CANCELED)
      membership_without_order(gold_offer, code: 'SHORT', member_since: Date.new(2026, 1, 15),
                                           ended_at: Date.new(2026, 4, 15), status: Membership::EXPIRED)
      membership_without_order(gold_offer, code: 'BEFORE', member_since: Date.new(2025, 1, 1),
                                           ended_at: Date.new(2025, 12, 1), status: Membership::CANCELED)
      membership_without_order(gold_offer, code: 'RUNNING', member_since: Date.new(2025, 1, 1))
      membership_without_order(gold_offer, code: 'JOINED', member_since: Date.new(2026, 5, 1))
      membership_without_order(gold_offer, code: 'NEVER', member_since: Date.new(2026, 2, 1),
                                           status: Membership::PENDING)
    end

    let(:gold) { stats_for(analyze, gold_offer) }

    it 'counts memberships that began in the range as new, ignoring Pending ones' do
      expect(gold.new_count).to eq(2) # SHORT and JOINED
    end

    it 'counts memberships that ended in the range as dropped' do
      expect(gold.dropped_count).to eq(2) # LONG and SHORT; BEFORE ended before the range
    end

    it 'averages the whole length of ended memberships and of active ones up to the range end' do
      # LONG 424 days, SHORT 90, RUNNING 545 (to 2026-06-30), JOINED 60 (to 2026-06-30);
      # BEFORE ended before the range and NEVER never began.
      expect(gold.avg_length_days).to eq(BigDecimal('1119') / 4)
    end
  end

  describe 'memberships whose records disagree with their payments' do
    it 'counts a Pending membership that paid, through its paid-through date' do
      membership_with_order(gold_offer, code: 'PEND1', member_since: Date.new(2026, 1, 10), status: Membership::PENDING,
                                        collected: [[30, Time.zone.local(2026, 1, 10, 12)],
                                                    [30, Time.zone.local(2026, 2, 10, 12)]])

      gold = stats_for(analyze, gold_offer)

      # Paid through 2026-03-10 (last payment plus one month).
      expect(gold).to have_attributes(memberships_in_range: 1, memberships_active_at_end: 0, new_count: 1,
                                      dropped_count: 1, avg_length_days: 59)
      expect(gold.economics_per_month).to have_attributes(membership_count: 1)
      expect(analyze(from: Date.new(2026, 3, 11)).total.memberships_in_range).to eq(0)
    end

    it 'extends a membership that kept paying after its ended_at' do
      membership_with_order(gold_offer, code: 'LATE1', member_since: Date.new(2024, 1, 1),
                                        ended_at: Date.new(2025, 6, 1), status: Membership::CANCELED,
                                        collected: [[30, Time.zone.local(2026, 2, 10, 12)]])

      expect(analyze.total).to have_attributes(memberships_in_range: 1, memberships_active_at_end: 0,
                                               dropped_count: 1)
    end

    it 'does not let a refund extend a membership' do
      membership_with_order(gold_offer, code: 'REFUND1', member_since: Date.new(2026, 1, 10),
                                        ended_at: Date.new(2026, 2, 1), status: Membership::CANCELED,
                                        collected: [[30, Time.zone.local(2026, 1, 10, 12)],
                                                    [-30, Time.zone.local(2026, 5, 1, 12)]])

      # Paid through 2026-02-10, so it does not reach a range starting in March.
      expect(analyze(from: Date.new(2026, 3, 1)).total.memberships_in_range).to eq(0)
    end

    it 'leaves out a Pending membership whose only payment was $0' do
      membership_with_order(gold_offer, code: 'TRIAL1', member_since: Date.new(2026, 1, 10),
                                        status: Membership::PENDING,
                                        collected: [[0, Time.zone.local(2026, 1, 10, 12)]])

      expect(analyze.total.memberships_in_range).to eq(0)
    end
  end

  describe "paid-through windows follow the offer's billing period" do
    def lapsed_member(code, paid_on, amount = 420)
      membership_with_order(gold_offer, code: code, member_since: paid_on.to_date, status: Membership::SUSPENDED,
                                        collected: [[amount, paid_on]])
    end

    it 'keeps a lapsed yearly member counting through the year it paid for' do
      set_billing_period(gold_offer, MembershipOffer::YEAR)
      lapsed_member('YEARLY', Time.zone.local(2026, 1, 10, 12))

      expect(analyze.total).to have_attributes(memberships_active_at_end: 1, dropped_count: 0)
    end

    it 'closes a lapsed monthly member a month after their last payment' do
      set_billing_period(gold_offer, MembershipOffer::MONTH)
      lapsed_member('MONTHLY', Time.zone.local(2026, 1, 10, 12), 35)

      expect(analyze.total).to have_attributes(memberships_active_at_end: 0, dropped_count: 1)
    end

    it "runs a one-time price for the offer's gift length" do
      set_billing_period(gold_offer, MembershipOffer::ONE_TIME, nil)
      gold_offer.update_column(:max_cycles_if_gift, 6)
      lapsed_member('ONCE', Time.zone.local(2026, 1, 10, 12), 120)

      # Paid through 2026-07-10, past the range end.
      expect(analyze.total.memberships_active_at_end).to eq(1)
      expect(analyze(to: Date.new(2026, 7, 31)).total.memberships_active_at_end).to eq(0)
    end

    it 'runs a weekly price for its weeks' do
      set_billing_period(gold_offer, MembershipOffer::WEEK, 2)
      lapsed_member('WEEKLY', Time.zone.local(2026, 6, 1, 12), 20)

      # Paid through 2026-06-15.
      expect(analyze(from: Date.new(2026, 6, 14)).total.memberships_in_range).to eq(1)
      expect(analyze(from: Date.new(2026, 6, 16)).total.memberships_in_range).to eq(0)
    end
  end

  describe 'Suspended memberships' do
    it 'ends a Suspended membership at its ended_at when set' do
      membership_without_order(gold_offer, code: 'SUSP1', member_since: Date.new(2026, 1, 1),
                                           ended_at: Date.new(2026, 3, 31), status: Membership::SUSPENDED)

      expect(analyze.total).to have_attributes(memberships_in_range: 1, memberships_active_at_end: 0,
                                               dropped_count: 1, avg_length_days: 89)
    end

    it 'counts a Suspended membership without ended_at through its paid-through date, not after' do
      membership_with_order(gold_offer, code: 'SUSP2', member_since: Date.new(2026, 1, 10),
                                        collected: [[30, Time.zone.local(2026, 2, 10, 12)]],
                                        status: Membership::SUSPENDED)

      # Paid through 2026-03-10: last payment plus one month.
      expect(analyze.total).to have_attributes(memberships_in_range: 1, memberships_active_at_end: 0,
                                               dropped_count: 1, avg_length_days: 59)
      expect(analyze(to: Date.new(2026, 3, 5)).total.memberships_active_at_end).to eq(1)
      expect(analyze(from: Date.new(2026, 3, 11)).total.memberships_in_range).to eq(0)
    end

    it 'never counts a Suspended membership with no payments beyond its start' do
      membership_without_order(gold_offer, code: 'SUSP3', member_since: Date.new(2026, 2, 1),
                                           status: Membership::SUSPENDED)

      expect(analyze.total).to have_attributes(memberships_in_range: 1, memberships_active_at_end: 0)
      expect(analyze(from: Date.new(2026, 3, 1)).total.memberships_in_range).to eq(0)
    end
  end

  describe '.offer_ids_for_groups' do
    let(:retired_offer) do
      FactoryBot.create(:membership_offer, name: 'Retired', status: MembershipOffer::INACTIVE)
    end
    let(:offers) { MembershipOffer.all }

    def group_ids(groups = [described_class::WITH_ACTIVE_MEMBERSHIPS])
      described_class.offer_ids_for_groups(groups, offers, range_start, range_end)
    end

    it 'matches offers, active or not, with a membership active in the range' do
      membership_without_order(gold_offer, code: 'G1')
      membership_without_order(retired_offer, code: 'R1', member_since: Date.new(2025, 1, 1),
                                              ended_at: Date.new(2026, 2, 1), status: Membership::CANCELED)
      silver_offer

      expect(group_ids).to contain_exactly(gold_offer.id, retired_offer.id)
    end

    it 'skips offers whose memberships fall outside the range or never activated' do
      membership_without_order(gold_offer, code: 'G2', member_since: Date.new(2025, 1, 1),
                                           ended_at: Date.new(2025, 12, 31), status: Membership::CANCELED)
      membership_without_order(silver_offer, code: 'S2', status: Membership::PENDING)

      expect(group_ids).to be_empty
    end

    it 'only looks within the offers it is given' do
      membership_without_order(gold_offer, code: 'G3')

      expect(described_class.offer_ids_for_groups([described_class::WITH_ACTIVE_MEMBERSHIPS],
                                                  MembershipOffer.where(id: silver_offer.id), range_start, range_end))
        .to be_empty
    end

    it 'matches nothing for unknown or missing groups' do
      membership_without_order(gold_offer, code: 'G4')

      expect(group_ids(['everything'])).to be_empty
      expect(group_ids([])).to be_empty
    end
  end
end
