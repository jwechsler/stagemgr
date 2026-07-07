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

      expect(rows.pluck(:Month).uniq).to eq(['2026-05'])
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

    it 'scopes the monthly summary totals to that offer' do
      summary_row = rows.find { |row| row[:Offer] == MembershipUsageReport::ALL_OFFERS_LABEL }

      expect(summary_row).to include(Memberships: 1, Collected: 50.to_money, Paid: 20.to_money)
    end
  end
end
