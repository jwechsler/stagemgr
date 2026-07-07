require 'rails_helper'

RSpec.describe MembershipUsageReport do
  let(:starting_date) { Date.new(2026, 5, 1) }
  let(:ending_date) { Date.new(2026, 5, 31) }
  let(:in_may) { Time.zone.local(2026, 5, 10, 12, 0, 0) }

  let(:gold_offer) { FactoryBot.create(:membership_offer, name: 'Gold') }
  let(:silver_offer) { FactoryBot.create(:membership_offer, name: 'Silver') }

  def create_membership_order_for(offer, collected:, processed_on:)
    order = FactoryBot.create(:membership_order)
    order.membership_line_item.update!(membership_offer: offer)
    order.membership.update!(membership_offer: offer)
    order.payments.each { |payment| payment.update!(amount: collected, processed_on: processed_on) }
    order
  end

  def create_membership_payment_for(membership, paid:, processed_on:)
    ticket_order = FactoryBot.create(:ticket_order)
    FactoryBot.create(:membership_payment, order: ticket_order, membership: membership,
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

    it 'ends with a grand Total row summing the detail rows across all months' do
      total_row = rows.last

      expect(total_row).to include(Month: 'Total', Memberships: 2, Collected: 80.to_money, Paid: 30.to_money)
    end
  end

  describe '#create excluding the current month' do
    let(:this_month) { Time.current.change(day: 1, hour: 12) }
    let(:last_month) { (Time.current - 1.month).change(day: 15, hour: 12) }

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
      expect(months).to include((Time.current - 1.month).strftime('%Y-%m'))
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
      expect(report.data.last).to include(Month: 'Total', Memberships: 2, Collected: 80.to_money, Paid: 30.to_money)
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

      expect(total_row).to include(Month: 'Total', Memberships: 1, Collected: 50.to_money, Paid: 20.to_money)
    end
  end
end
