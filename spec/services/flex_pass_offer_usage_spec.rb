require 'rails_helper'

RSpec.describe FlexPassOfferUsage do
  let(:offer) { FactoryBot.create(:flex_pass_offer, number_of_tickets: 5) }
  let(:usage) { described_class.new(offer) }

  before { allow(Resque).to receive(:enqueue_in) }

  def sell_pass
    FactoryBot.create(:flex_pass_order, flex_pass_offer: offer).flex_pass_line_item.flex_pass
  end

  def redeem(pass, tickets)
    FactoryBot.create(:flex_pass_payment, order: pass.order, flex_pass: pass, number_of_tickets: tickets)
  end

  it 'reports zeros and no passes when none have been sold' do
    expect(usage).not_to be_passes
    expect([usage.passes_sold, usage.outstanding_count, usage.expired_count,
            usage.tickets_issued, usage.tickets_redeemed]).to eq([0, 0, 0, 0, 0])
  end

  it 'separates outstanding passes from expired, exhausted and cancelled ones' do
    outstanding = sell_pass
    sell_pass.update_columns(expiration_date: Date.current - 1)
    redeem(sell_pass, 5)
    sell_pass.update_columns(active: false)
    redeem(outstanding, 2)

    expect(usage).to be_passes
    expect(usage.passes_sold).to eq(4)
    expect(usage.outstanding_count).to eq(1)
    expect(usage.expired_count).to eq(1)
    expect(usage.tickets_issued).to eq(20)
    expect(usage.tickets_redeemed).to eq(7)
  end

  it 'counts a pass expiring today as outstanding, not expired' do
    sell_pass.update_columns(expiration_date: Date.current)

    expect(usage.outstanding_count).to eq(1)
    expect(usage.expired_count).to eq(0)
  end

  it 'ignores non-flex-pass payments that carry a flex_pass_id' do
    pass = sell_pass
    redeem(pass, 1)
    FactoryBot.create(:cash_payment, order: pass.order, amount: 10).update_columns(flex_pass_id: pass.id, number_of_tickets: 3)

    expect(usage.tickets_redeemed).to eq(1)
    expect(usage.outstanding_count).to eq(1)
  end

  it 'ignores passes of other offers' do
    FactoryBot.create(:flex_pass_order)

    expect(usage.passes_sold).to eq(0)
  end
end
