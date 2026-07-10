require 'rails_helper'

RSpec.describe MembershipUsageReport do
  let(:starting_date) { Date.new(2026, 5, 1) }
  let(:ending_date) { Date.new(2026, 5, 31) }
  let(:in_may) { Time.zone.local(2026, 5, 10, 12, 0, 0) }

  let(:gold_offer) { FactoryBot.create(:membership_offer, name: 'Gold') }
  let(:silver_offer) { FactoryBot.create(:membership_offer, name: 'Silver') }

  def create_membership_order_for(offer, collected:, processed_on:, member_since: nil, ended_at: nil)
    order = FactoryBot.create(:membership_order)
    order.membership_line_item.update!(membership_offer: offer)
    order.membership.update!(membership_offer: offer, member_since: member_since || processed_on.to_date,
                             ended_at: ended_at)
    order.payments.each { |payment| payment.update!(amount: collected, processed_on: processed_on) }
    order
  end

  def create_membership_payment_for(membership, paid:, processed_on:)
    ticket_order = FactoryBot.create(:ticket_order)
    FactoryBot.create(:membership_payment, order: ticket_order, membership: membership, number_of_tickets: 1,
                                           amount: paid, processed_on: processed_on)
  end

  describe '#create' do
    subject(:report_output) { described_class.new(starting_date, ending_date).create }

    let(:headers) { report_output.first }
    let(:rows) { report_output.last }

    before do
      gold_order = create_membership_order_for(gold_offer, collected: 50.0, processed_on: in_may)
      silver_order = create_membership_order_for(silver_offer, collected: 30.0, processed_on: in_may)

      create_membership_payment_for(gold_order.membership, paid: 20.0, processed_on: in_may)
      create_membership_payment_for(silver_order.membership, paid: 10.0, processed_on: in_may)
    end

    it 'includes an Offer column in the headers' do
      expect(headers).to eq(%i[Month Offer Memberships Collected Paid])
    end

    it 'breaks out each month by membership offer' do
      gold_row = rows.find { |row| row[:Month] == '2026-05' && row[:Offer] == 'Gold' }

      expect(gold_row).to include(Memberships: 1, Collected: 50.to_money, Paid: 20.to_money,
                                  display_class: :report_detail_row)
    end

    it 'reports each offer independently' do
      silver_row = rows.find { |row| row[:Month] == '2026-05' && row[:Offer] == 'Silver' }

      expect(silver_row).to include(Memberships: 1, Collected: 30.to_money, Paid: 10.to_money,
                                    display_class: :report_detail_row)
    end

    it 'keeps the aggregate monthly totals as a summary row' do
      summary_row = rows.find do |row|
        row[:Month] == '2026-05' && row[:Offer] == MembershipUsageReport::ALL_OFFERS_LABEL
      end

      expect(summary_row).to include(Memberships: 2, Collected: 80.to_money, Paid: 30.to_money,
                                     display_class: :report_summary_row)
    end

    it 'lists offer rows above the monthly summary row' do
      may_offers = rows.select { |row| row[:Month] == '2026-05' }.pluck(:Offer)

      expect(may_offers).to eq(['Gold', 'Silver', MembershipUsageReport::ALL_OFFERS_LABEL])
    end

    it 'only counts MembershipPayment rows toward Paid, despite the Payment.descendants override' do
      # The credit card payments created on the membership orders above (50 + 30)
      # must not leak into Paid via the broadened MembershipPayment STI scope.
      summary_row = rows.find { |row| row[:Offer] == MembershipUsageReport::ALL_OFFERS_LABEL }

      expect(summary_row[:Paid]).to eq(30.to_money)
    end

    it 'excludes activity outside the reporting window' do
      create_membership_order_for(gold_offer, collected: 99.0, processed_on: Time.zone.local(2026, 7, 1, 12, 0, 0))

      months = rows.reject { |row| row[:Month] == 'Total' }.pluck(:Month).uniq
      expect(months).to eq(['2026-05'])
    end

    it 'ends with a grand Total row summing the money columns but not Memberships' do
      total_row = rows.last

      expect(total_row).to include(Month: 'Total', Memberships: '', Collected: 80.to_money, Paid: 30.to_money)
    end
  end

  describe 'active-in-month membership counting' do
    let(:march) { Time.zone.local(2026, 3, 10, 12, 0, 0) }

    def rows_for(range_start, range_end)
      described_class.new(range_start, range_end).create.last
    end

    def memberships_by_month(rows)
      rows.select { |row| row[:display_class] == :report_detail_row }
          .to_h { |row| [row[:Month], row[:Memberships]] }
    end

    it 'counts a membership in every month of its active window, not just billing months' do
      create_membership_order_for(gold_offer, collected: 50.0, processed_on: march)

      rows = rows_for(Date.new(2026, 3, 1), Date.new(2026, 5, 31))

      expect(memberships_by_month(rows)).to eq('2026-03' => 1, '2026-04' => 1, '2026-05' => 1)
    end

    it 'produces a row for months with active memberships but no payments' do
      create_membership_order_for(gold_offer, collected: 50.0, processed_on: march)

      april_row = rows_for(Date.new(2026, 4, 1), Date.new(2026, 4, 30))
                  .find { |row| row[:Month] == '2026-04' && row[:Offer] == 'Gold' }

      expect(april_row).to include(Memberships: 1, Collected: 0.to_money, Paid: 0.to_money)
    end

    it 'counts a canceled membership through its ended_at month and not after' do
      create_membership_order_for(gold_offer, collected: 50.0, processed_on: march,
                                              ended_at: Date.new(2026, 4, 15))

      rows = rows_for(Date.new(2026, 3, 1), Date.new(2026, 5, 31))

      expect(memberships_by_month(rows)).to eq('2026-03' => 1, '2026-04' => 1)
    end

    it 'never counts memberships whose status is Pending' do
      order = create_membership_order_for(gold_offer, collected: 50.0, processed_on: march)
      order.membership.update!(status: Membership::PENDING)

      march_row = rows_for(Date.new(2026, 3, 1), Date.new(2026, 3, 31))
                  .find { |row| row[:Month] == '2026-03' && row[:Offer] == 'Gold' }

      # The collected payment still reports (money moved), but the
      # never-activated membership itself doesn't count.
      expect(march_row).to include(Memberships: 0, Collected: 50.to_money)
    end

    it 'counts Suspended memberships as active' do
      order = create_membership_order_for(gold_offer, collected: 50.0, processed_on: march)
      order.membership.update!(status: Membership::SUSPENDED)

      rows = rows_for(Date.new(2026, 3, 1), Date.new(2026, 3, 31))

      expect(memberships_by_month(rows)).to eq('2026-03' => 1)
    end

    it 'uses the Stripe start_date over member_since when present' do
      order = create_membership_order_for(gold_offer, collected: 50.0, processed_on: march,
                                                      member_since: Date.new(2026, 3, 10))
      order.membership.update!(start_date: Date.new(2026, 4, 2))

      rows = rows_for(Date.new(2026, 3, 1), Date.new(2026, 4, 30))

      # March still gets a row for the collected payment, but the membership
      # itself doesn't count until its Stripe start_date month.
      expect(memberships_by_month(rows)).to eq('2026-03' => 0, '2026-04' => 1)
    end
  end

  describe '#create with an order-less library pass' do
    let(:library_offer) { FactoryBot.create(:membership_offer, :timed, name: 'Library Pass') }
    let(:library_pass) do
      FactoryBot.create(:library_pass, membership_offer: library_offer, member_since: Date.new(2026, 5, 3))
    end

    subject(:rows) { described_class.new(starting_date, ending_date).create.last }

    before do
      create_membership_payment_for(library_pass, paid: 24.0, processed_on: in_may)
    end

    it 'counts the pass as a membership with its redemptions in Paid and nothing Collected' do
      library_row = rows.find { |row| row[:Month] == '2026-05' && row[:Offer] == 'Library Pass' }

      expect(library_row).to include(Memberships: 1, Collected: 0.to_money, Paid: 24.to_money,
                                     display_class: :report_detail_row)
    end

    it 'stops counting the pass after staff cancel it' do
      library_pass.update!(status: Membership::CANCELED, ended_at: Date.new(2026, 5, 20))

      june_rows = described_class.new(Date.new(2026, 6, 1), Date.new(2026, 6, 30)).create.last
                                 .select { |row| row[:display_class] == :report_detail_row }

      expect(june_rows).to be_empty
    end
  end

  describe '#create excluding the current month' do
    let(:this_month) { Time.current.change(day: 1, hour: 12) }
    let(:last_month) { 1.month.ago.change(day: 15, hour: 12) }

    subject(:months) do
      described_class.new(last_month.to_date, this_month.to_date.at_end_of_month)
                     .create.last
                     .reject { |row| row[:Month] == 'Total' }
                     .pluck(:Month).uniq
    end

    before do
      create_membership_order_for(gold_offer, collected: 40.0, processed_on: this_month)
      create_membership_order_for(gold_offer, collected: 25.0, processed_on: last_month)
    end

    it 'omits the current (incomplete) month even when the range includes it' do
      expect(months).not_to include(Time.current.strftime('%Y-%m'))
    end

    it 'still includes prior complete months' do
      expect(months).to include(1.month.ago.strftime('%Y-%m'))
    end
  end

  describe '#create for a CSV download' do
    # A non-nil reporting_user_id routes the report to the CSV/download path.
    subject(:report) { described_class.new(starting_date, ending_date, 999) }

    before do
      gold_order = create_membership_order_for(gold_offer, collected: 50.0, processed_on: in_may)
      silver_order = create_membership_order_for(silver_offer, collected: 30.0, processed_on: in_may)
      create_membership_payment_for(gold_order.membership, paid: 20.0, processed_on: in_may)
      create_membership_payment_for(silver_order.membership, paid: 10.0, processed_on: in_may)

      # Skip the actual file/FileStore write; we only inspect the built rows.
      allow(report).to receive(:report_data)
      report.create
    end

    it 'suppresses the All Offers monthly subtotals' do
      expect(report.data.pluck(:Offer)).not_to include(MembershipUsageReport::ALL_OFFERS_LABEL)
    end

    it 'still includes the per-offer detail rows' do
      expect(report.data.pluck(:Offer)).to include('Gold', 'Silver')
    end

    it 'still ends with a grand Total row' do
      expect(report.data.last).to include(Month: 'Total', Memberships: '', Collected: 80.to_money, Paid: 30.to_money)
    end
  end

  describe '#create scoped to a single offer' do
    subject(:rows) { described_class.new(starting_date, ending_date, nil, gold_offer.id).create.last }

    before do
      gold_order = create_membership_order_for(gold_offer, collected: 50.0, processed_on: in_may)
      silver_order = create_membership_order_for(silver_offer, collected: 30.0, processed_on: in_may)
      create_membership_payment_for(gold_order.membership, paid: 20.0, processed_on: in_may)
      create_membership_payment_for(silver_order.membership, paid: 10.0, processed_on: in_may)
    end

    it 'includes only the requested offer in the detail rows' do
      detail_offers = rows.select { |row| row[:display_class] == :report_detail_row }.pluck(:Offer)

      expect(detail_offers).to eq(['Gold'])
    end

    it 'reports the offer totals for the month' do
      gold_row = rows.find { |row| row[:Month] == '2026-05' && row[:Offer] == 'Gold' }

      expect(gold_row).to include(Memberships: 1, Collected: 50.to_money, Paid: 20.to_money)
    end

    it 'suppresses the All Offers monthly subtotal' do
      expect(rows.pluck(:Offer)).not_to include(MembershipUsageReport::ALL_OFFERS_LABEL)
    end

    it 'ends with a grand Total row for the single offer' do
      total_row = rows.last

      expect(total_row).to include(Month: 'Total', Memberships: '', Collected: 50.to_money, Paid: 20.to_money)
    end
  end

  describe '#create scoped to several offers' do
    let(:bronze_offer) { FactoryBot.create(:membership_offer, name: 'Bronze') }

    subject(:rows) do
      described_class.new(starting_date, ending_date, nil, [gold_offer.id, silver_offer.id]).create.last
    end

    before do
      gold_order = create_membership_order_for(gold_offer, collected: 50.0, processed_on: in_may)
      silver_order = create_membership_order_for(silver_offer, collected: 30.0, processed_on: in_may)
      create_membership_order_for(bronze_offer, collected: 15.0, processed_on: in_may)
      create_membership_payment_for(gold_order.membership, paid: 20.0, processed_on: in_may)
      create_membership_payment_for(silver_order.membership, paid: 10.0, processed_on: in_may)
    end

    it 'includes only the requested offers in the detail rows' do
      detail_offers = rows.select { |row| row[:display_class] == :report_detail_row }.pluck(:Offer)

      expect(detail_offers).to contain_exactly('Gold', 'Silver')
    end

    it 'aggregates the monthly subtotal over just the selected offers' do
      summary_row = rows.find { |row| row[:Offer] == MembershipUsageReport::ALL_OFFERS_LABEL }

      expect(summary_row).to include(Memberships: 2, Collected: 80.to_money, Paid: 30.to_money)
    end

    it 'ends with a grand Total row over the selected offers' do
      expect(rows.last).to include(Month: 'Total', Memberships: '', Collected: 80.to_money, Paid: 30.to_money)
    end
  end
end
