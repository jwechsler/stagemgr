# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LglReplicateDonationJob do
  let(:client) { instance_double(Lgl::Client) }
  let(:order) { FactoryBot.create(:donation_order_for_one_thousand_dollars) }
  let(:replicator) { instance_double(Lgl::GiftReplicator) }
  let(:outcome) { Lgl::GiftReplicator::Outcome.new(:created, 7001, 'gift written') }

  before do
    allow(Lgl).to receive(:enabled?).and_return(true)
    allow(Lgl).to receive(:client).and_return(client)
    allow(Lgl::GiftReplicator).to receive(:new).and_return(replicator)
    allow(replicator).to receive_messages(replicate: outcome, note_refund: outcome)
  end

  it 'does nothing when LGL is disabled: no LGL call, one log line' do
    allow(Lgl).to receive(:enabled?).and_return(false)
    allow(Rails.logger).to receive(:info)

    expect(described_class.perform(order.id)).to be_nil

    expect(Lgl).not_to have_received(:client)
    expect(Lgl::GiftReplicator).not_to have_received(:new)
    expect(Rails.logger).to have_received(:info).with(a_string_including('skipped', 'littlegreenlight.sync')).once
  end

  it 'ignores an unknown order id' do
    expect(described_class.perform(0)).to be_nil
    expect(Lgl::GiftReplicator).not_to have_received(:new)
  end

  it 'ignores an order that is not a donation' do
    ticket_order = FactoryBot.create(:ticket_order)

    expect(described_class.perform(ticket_order.id)).to be_nil
    expect(Lgl::GiftReplicator).not_to have_received(:new)
  end

  it 'replicates the gift by default and logs one line' do
    allow(Rails.logger).to receive(:info)

    expect(described_class.perform(order.id)).to eq(outcome)

    expect(Lgl::GiftReplicator).to have_received(:new).with(order, client)
    expect(replicator).to have_received(:replicate)
    expect(replicator).not_to have_received(:note_refund)
    expect(Rails.logger).to have_received(:info)
      .with("[LGL] order ##{order.id}: gift created 7001 (gift written; action: gift)").once
  end

  it 'notes a refund on the refund action' do
    described_class.perform(order.id, described_class::REFUND_ACTION)

    expect(replicator).to have_received(:note_refund)
    expect(replicator).not_to have_received(:replicate)
  end

  it 'lets NotLinked raise so resque-retry backs off' do
    allow(replicator).to receive(:replicate).and_raise(Lgl::GiftReplicator::NotLinked, 'not yet')

    expect { described_class.perform(order.id) }.to raise_error(Lgl::GiftReplicator::NotLinked)
    expect(described_class.retry_exception?(Lgl::GiftReplicator::NotLinked)).to be(true)
  end

  it 'backs off along its strategy before giving up' do
    expect(described_class.retry_limit).to eq(5)
    expect(described_class.retry_delay).to eq(60)
    described_class.instance_variable_set(:@retry_attempt, 4)
    expect(described_class.retry_delay).to eq(21_600)
  ensure
    described_class.instance_variable_set(:@retry_attempt, nil)
  end

  it 'uses one lock per order whatever the action' do
    expect(described_class.redis_lock_key(5, described_class::GIFT_ACTION))
      .to eq(described_class.redis_lock_key(5, described_class::REFUND_ACTION))
    expect(described_class.redis_lock_key(5)).not_to eq(described_class.redis_lock_key(6))
  end

  # resque-scheduler enqueues delayed jobs inside a Redis MULTI; a @loner's
  # enqueue-time lock check then raised NoMethodError (to_i on Redis::Future)
  # and the delayed run was silently dropped.
  it 'takes no enqueue-time lock, only a perform-time one' do
    expect(described_class.instance_variable_get(:@loner)).to be_falsey
    expect(described_class.lock_timeout).to be_positive
  end

  it 'survives resque-scheduler moving a delayed run onto the maintenance queue' do
    allow(Resque::Scheduler).to receive(:am_master).and_return(true) # its master lock is Lua; fakeredis has none
    Resque.enqueue_in(2.minutes, described_class, order.id, described_class::REFUND_ACTION)
    timestamp = Resque.next_delayed_timestamp(2.minutes.from_now)

    Resque::Scheduler.enqueue_delayed_items_for_timestamp(timestamp)

    expect(Resque.peek(:maintenance)).to eq('class' => described_class.name,
                                            'args' => [order.id, described_class::REFUND_ACTION])
  end
end
