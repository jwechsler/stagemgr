require 'rails_helper'

# A refund and an exchange of one order, or two exchanges of it, started at
# the same moment: both lock the order's row first (Order#refund!,
# ExchangeRefundable#lock_exchange_source!), so the second waits for the
# first to commit, then re-reads the order and is refused. Without the locks
# both read a sold order and both succeed (a refunded order also exchanged).
#
# Each thread needs its own committed view of the data, so this runs outside
# the per-example transaction (:concurrent_db) and deletes what it created.
module ExchangeRefundRace
  # Held inside each transaction just after its lock, so the other thread
  # reliably arrives while the first still holds the row.
  RACE_WINDOW_SECONDS = 0.2
  THREAD_JOIN_TIMEOUT = 30
  REFUSALS = [Order::RefundNotAllowed, ExchangeRefundable::ExchangeNotPossible].freeze
end

RSpec.describe 'Concurrent refunds and exchanges of one order', :concurrent_db do
  self.use_transactional_tests = false

  include ConcurrentDbSnapshot

  around { |example| with_db_snapshot { example.run } }

  before do
    %i[prepare_exchange_from refund_payments!].each do |method|
      allow_any_instance_of(TicketOrder).to receive(method).and_wrap_original do |original, *args|
        sleep ExchangeRefundRace::RACE_WINDOW_SECONDS
        original.call(*args)
      end
    end
  end

  let(:original) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash) }

  # A same-price cash exchange, so no gateway is involved.
  def new_exchange_order(days_later = 1)
    performance = original.performance.dup
    performance.performance_date = original.performance.performance_date + days_later.days
    performance.performance_code += SecureRandom.hex(2).upcase
    performance.save!
    FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance.reload,
                                                             payment_type: original.payment_type)
  end

  # Each job gets its own connection and its own freshly loaded orders (loaded
  # before the barrier, as two staff pages would be). Returns :ok or the error.
  def race(*jobs)
    barrier = Concurrent::CyclicBarrier.new(jobs.size)
    threads = jobs.map do |job|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          action = job.call
          barrier.wait
          action.call
          :ok
        rescue StandardError => e
          e
        end
      end
    end
    threads.map { |t| t.join(ExchangeRefundRace::THREAD_JOIN_TIMEOUT)&.value || :timed_out }
  end

  def refund_job
    lambda do
      order = TicketOrder.find(original.id)
      -> { order.refund! }
    end
  end

  def exchange_job(exchange)
    lambda do
      source = TicketOrder.find(original.id)
      order = TicketOrder.find(exchange.id)
      -> { order.exchange_and_process_from!(source) }
    end
  end

  def expect_one_winner(results)
    expect(results.count(:ok)).to eq(1), results.inspect
    refusal = (results - [:ok]).first
    expect(ExchangeRefundRace::REFUSALS.any? { |klass| refusal.is_a?(klass) }).to be(true), refusal.inspect
  end

  it 'lets exactly one of a refund and an exchange through' do
    exchange = new_exchange_order

    results = race(refund_job, exchange_job(exchange))

    expect_one_winner(results)
    original.reload
    if results.first == :ok
      expect(original.status).to eq(Order::REFUNDED)
      expect(exchange.reload.status).to eq(Order::NEW)
      expect(original.payments.grep(ExchangePayment)).to be_empty
    else
      expect(original.status).to eq(Order::EXCHANGED)
      expect(exchange.reload.status).to eq(Order::PROCESSED)
      expect(original.payments.grep(CashPayment).map(&:amount)).to all(be_positive)
    end
    expect(original.payments.sum(&:amount)).to eq(0)
  end

  it 'lets exactly one of two exchanges through' do
    exchanges = [new_exchange_order(1), new_exchange_order(2)]

    results = race(*exchanges.map { |exchange| exchange_job(exchange) })

    expect_one_winner(results)
    expect(results.grep(ExchangeRefundable::ExchangeNotPossible).first.message).to include('can no longer be exchanged')
    expect(original.reload.status).to eq(Order::EXCHANGED)
    expect(exchanges.map { |exchange| exchange.reload.status }).to contain_exactly(Order::PROCESSED, Order::NEW)
    expect(original.payments.grep(ExchangePayment).size).to eq(1)
  end
end
