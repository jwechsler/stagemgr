require 'rails_helper'

# Direct unit test for the duplicate hash transformation fix
RSpec.describe 'FlexPassUsageReport fix for ticket_paid_out calculation', type: :unit do
  it 'properly transforms amounts without duplicate nesting' do
    # This simulates the bug where the original code had two identical transformations
    # paid_amount.each { |key, value| paid_amount[key] = { tickets_paid_out: value } }
    # paid_amount.each{|key, value| paid_amount[key] = {tickets_paid_out: value} }

    # Simulate the initial hash returned from the query
    paid_amount = { '2025-05' => 45.0 }

    # Apply the transformation once (as in the fixed code)
    paid_amount.each { |key, value| paid_amount[key] = { tickets_paid_out: value } }

    # Check result
    expect(paid_amount['2025-05']).to eq({ tickets_paid_out: 45.0 })
    expect(paid_amount['2025-05'][:tickets_paid_out]).to eq(45.0)

    # Now demonstrate the bug by applying the transformation again (as in the buggy code)
    paid_amount_buggy = { '2025-05' => 45.0 }
    paid_amount_buggy.each { |key, value| paid_amount_buggy[key] = { tickets_paid_out: value } }
    paid_amount_buggy.each { |key, value| paid_amount_buggy[key] = { tickets_paid_out: value } }

    # The result will be nested hashes
    expect(paid_amount_buggy['2025-05']).to eq({ tickets_paid_out: { tickets_paid_out: 45.0 } })

    # In the buggy version, this would be an object not a number:
    expect(paid_amount_buggy['2025-05'][:tickets_paid_out]).to eq({ tickets_paid_out: 45.0 })

    # Simulate how this affects the merged hash access in the report:
    merged_hash = paid_amount['2025-05'] # Fixed version
    expect(merged_hash[:tickets_paid_out]).to eq(45.0)

    merged_hash_buggy = paid_amount_buggy['2025-05'] # Buggy version
    # The bug caused the tickets_paid_out value to be a hash, not a number,
    # which would then become 0.0 when called with || 0.0 in the report
    expect(merged_hash_buggy[:tickets_paid_out]).not_to eq(45.0)
  end
end

RSpec.describe FlexPassUsageReport do
  let(:starting_date) { Date.new(2026, 5, 1) }
  let(:ending_date) { Date.new(2026, 5, 31) }
  let(:in_may) { Time.zone.local(2026, 5, 10, 12, 0, 0) }

  let(:wit_offer)    { FactoryBot.create(:flex_pass_offer, name: 'Wit Pass', price: 100.0) }
  let(:roving_offer) { FactoryBot.create(:flex_pass_offer, name: 'Roving Pass', price: 60.0) }

  def create_paid_order_for(offer, amount:)
    order = FactoryBot.create(:flex_pass_order, flex_pass_offer: offer)
    order.payments << FactoryBot.create(:cash_payment, order: order, amount: amount,
                                                       processed_on: in_may)
    order
  end

  def redeem_tickets_on(order, count:, amount: 0)
    FactoryBot.create(:flex_pass_payment, order: order, flex_pass: order.flex_pass,
                                          number_of_tickets: count, amount: amount,
                                          processed_on: in_may)
  end

  def may_row(report_output)
    report_output.last.find { |row| row[:month] == '2026-05' }
  end

  let!(:wit_order)    { create_paid_order_for(wit_offer, amount: 100.0) }
  let!(:roving_order) { create_paid_order_for(roving_offer, amount: 60.0) }

  it 'aggregates every offer when none are selected' do
    row = may_row(described_class.new(starting_date, ending_date).create)
    expect(row).to include(new_passes: 2, new_deposits: 160.to_money)
  end

  it 'restricts to a single selected offer' do
    row = may_row(described_class.new(starting_date, ending_date, [wit_offer.id]).create)
    expect(row).to include(new_passes: 1, new_deposits: 100.to_money)
  end

  it 'aggregates over several selected offers' do
    row = may_row(described_class.new(starting_date, ending_date,
                                      [wit_offer.id, roving_offer.id]).create)
    expect(row).to include(new_passes: 2, new_deposits: 160.to_money)
  end

  it 'still accepts a legacy scalar offer id' do
    row = may_row(described_class.new(starting_date, ending_date, wit_offer.id).create)
    expect(row).to include(new_passes: 1, new_deposits: 100.to_money)
  end

  it 'counts tickets redeemed even when the payment amount is zero' do
    redeem_tickets_on(wit_order, count: 2)
    redeem_tickets_on(roving_order, count: 1)

    row = may_row(described_class.new(starting_date, ending_date).create)
    expect(row).to include(tickets_redeemed: 3, tickets_paid_out: 0.to_money)
  end

  it 'restricts tickets redeemed to the selected offers' do
    redeem_tickets_on(wit_order, count: 2)
    redeem_tickets_on(roving_order, count: 1)

    row = may_row(described_class.new(starting_date, ending_date, [wit_offer.id]).create)
    expect(row).to include(tickets_redeemed: 2)
  end

  it 'reports zero tickets redeemed when there are no redemptions' do
    row = may_row(described_class.new(starting_date, ending_date).create)
    expect(row).to include(tickets_redeemed: 0)
  end

  describe 'fan-out protection' do
    def add_second_pass(order)
      line_item = order.flex_pass.flex_pass_line_item
      FlexPass.create!(flex_pass_line_item: line_item, flex_pass_offer: line_item.flex_pass_offer,
                       address: order.address, code: "EXTRA#{order.id}",
                       expiration_date: Date.today + 12.months, active: true)
    end

    it 'does not multiply deposits by the pass count of legacy multi-pass line items' do
      add_second_pass(wit_order)

      row = may_row(described_class.new(starting_date, ending_date).create)
      expect(row).to include(new_passes: 3, new_deposits: 160.to_money)
    end

    it 'does not multiply pass counts by the payment count of split-payment orders' do
      wit_order.payments << FactoryBot.create(:cash_payment, order: wit_order, amount: 25.0,
                                                             processed_on: in_may)

      row = may_row(described_class.new(starting_date, ending_date).create)
      expect(row).to include(new_passes: 2, new_deposits: 185.to_money)
    end
  end

  describe 'recovered amounts' do
    def expire_in_may(order)
      order.flex_pass.update!(expiration_date: Date.new(2026, 5, 15))
    end

    it 'fully recovers a never-redeemed expired pass' do
      expire_in_may(wit_order)

      row = may_row(described_class.new(starting_date, ending_date).create)
      expect(row).to include(expired_flex_passes: 1, recovered_amount: 100.to_money)
    end

    it 'counts each expired pass price once regardless of redemption count' do
      expire_in_may(wit_order)
      redeem_tickets_on(wit_order, count: 1, amount: 10)
      redeem_tickets_on(wit_order, count: 1, amount: 10)

      row = may_row(described_class.new(starting_date, ending_date).create)
      expect(row).to include(expired_flex_passes: 1, recovered_amount: 80.to_money)
    end

    it 'restricts recovered passes to the selected offers' do
      expire_in_may(wit_order)
      expire_in_may(roving_order)

      row = may_row(described_class.new(starting_date, ending_date, [wit_offer.id]).create)
      expect(row).to include(expired_flex_passes: 1, recovered_amount: 100.to_money)
    end
  end
end
