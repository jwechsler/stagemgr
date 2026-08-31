require 'rails_helper'

# TicketOrder#resourced_stock_available is the hard block on a
# ResourcedTicketClass device pool (e.g. 10 captioning tablets shared across
# venues). It runs on every save, so it covers web checkout, the box office, the
# PROCESSED gate (Order#transition_processing_to_processed! saves only `if
# valid?`, before the payment is taken), exchanges, holds and bulk imports.
#
# Build technique follows spec/models/orders/ticket_order_mixed_seating_spec.rb.
RSpec.describe 'TicketOrder resourced equipment limits' do
  let(:venue_a) { FactoryBot.create(:venue) }
  let(:venue_b) { FactoryBot.create(:venue) }
  let(:theater) { FactoryBot.create(:theater) }
  let(:show_date) { Date.current + 30.days }

  # 2 tablets, 30 minute changeover, shared between both venues.
  let(:resource) do
    FactoryBot.create(:resourced_ticket_class, quantity: 2, changeover_minutes: 30,
                                               venues: [venue_a, venue_b])
  end

  let(:prod_a) { FactoryBot.create(:production, venue: venue_a, theater: theater, running_time: 120) }
  let(:prod_b) { FactoryBot.create(:production, venue: venue_b, theater: theater, running_time: 120) }

  # performance_time is a plain TIME column and is not zone-aware: a bare
  # (system zone) Time is what stores the hour asked for here.
  def performance_at(production, time_string, date: show_date)
    FactoryBot.create(:performance, production: production,
                                    performance_date: date,
                                    performance_time: Time.parse("#{date} #{time_string}"))
  end

  def shadow_for(production)
    tc = TicketClass.find_or_initialize_by(production_id: production.id,
                                           resourced_ticket_class_id: resource.id)
    tc.synced_from_resource = true
    tc.attributes = resource.shadow_attributes
    tc.save!
    tc
  end

  def allocate(shadow, performance, ticket_limit: nil)
    tca = TicketClassAllocation.find_or_create_by!(performance: performance, ticket_class: shadow)
    tca.update!(available: true, ticket_limit: ticket_limit)
    performance.ticket_class_allocations.reload
    tca
  end

  def build_order(performance, shadow, count, status: Order::NEW, **attrs)
    order = TicketOrder.new(status: status, performance: performance,
                            address: FactoryBot.create(:address),
                            payment_type: FactoryBot.create(:cash_payment_type),
                            **attrs)
    order.ticket_line_items << TicketLineItem.new(ticket_class: shadow, ticket_count: count)
    order
  end

  def sell(performance, shadow, count, status: Order::PROCESSED)
    order = build_order(performance, shadow, count, status: status)
    order.save!
    order
  end

  describe 'cross-venue exhaustion' do
    # A: 14:00 curtain, 120 min run, 30 min changeover -> devices busy 13:30-16:30
    # B: 15:00 curtain -> devices busy 14:30-17:30. The windows overlap, so the
    # two performances compete for the same two tablets.
    let(:perf_a) { performance_at(prod_a, '14:00') }
    let(:perf_b) { performance_at(prod_b, '15:00') }
    let(:shadow_a) { shadow_for(prod_a) }
    let(:shadow_b) { shadow_for(prod_b) }

    before do
      allocate(shadow_a, perf_a)
      allocate(shadow_b, perf_b)
    end

    it 'blocks a NEW order in venue B once venue A has taken the whole pool' do
      sell(perf_a, shadow_a, 2)

      order = build_order(perf_b, shadow_b, 1)
      expect(order).not_to be_valid
      expect(order.errors[:base].join).to match(/all '#{resource.class_name}' equipment is in use/)
      expect { order.save! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'reports the partial remainder when only some devices are committed' do
      sell(perf_a, shadow_a, 1)

      order = build_order(perf_b, shadow_b, 2)
      expect(order).not_to be_valid
      expect(order.errors[:base].join)
        .to match(/only 1 '#{resource.class_name}' available for this date and time/)
    end

    it 'allows exactly the remaining devices' do
      sell(perf_a, shadow_a, 1)

      expect(build_order(perf_b, shadow_b, 1)).to be_valid
    end

    it 'blocks the NEW -> PROCESSING save' do
      sell(perf_a, shadow_a, 2)
      order = build_order(perf_b, shadow_b, 1)
      order.status = Order::PROCESSING

      expect(order).not_to be_valid
      expect { order.save! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'blocks the PROCESSED gate before any payment is taken' do
      order = sell(perf_b, shadow_b, 1, status: Order::HOLD)
      # The other tablet goes to the overlapping performance in venue A.
      sell(perf_a, shadow_a, 1)

      # At the till the patron asks for a second tablet; there is none left.
      order.ticket_line_items.first.update!(ticket_count: 2)
      order.status = Order::PROCESSED
      # Order#transition_processing_to_processed! saves only `if valid?`, and the
      # charge happens after that, so an invalid order never reaches the gateway.
      expect(order).not_to be_valid
      expect(order.errors[:base].join).to match(/equipment is in use/)
    end

    it 'gives no bypass to a box office sale' do
      sell(perf_a, shadow_a, 2)

      order = build_order(perf_b, shadow_b, 1, box_office_sale: true)
      expect(order).not_to be_valid
      expect(order.errors[:base].join).to match(/equipment is in use/)
    end

    it 'ignores the order own devices so it can be re-saved' do
      order = sell(perf_b, shadow_b, 2)

      expect(order.reload).to be_valid
      expect(order.save).to be true
    end

    it 'frees the pool when the order is refunded' do
      order = sell(perf_a, shadow_a, 2)
      expect(build_order(perf_b, shadow_b, 1)).not_to be_valid

      order.update!(status: Order::REFUNDED)
      expect(build_order(perf_b, shadow_b, 1)).to be_valid
    end

    it 'lets a same-pool exchange proceed at exactly-full capacity' do
      # The source order releases (RELEASING is excluded from the pool) while the
      # replacement order is EXCHANGING, so the device carries across.
      source = sell(perf_a, shadow_a, 2)
      source.update!(status: Order::RELEASING)

      expect(build_order(perf_a, shadow_a, 2, status: Order::EXCHANGING)).to be_valid
    end
  end

  describe 'disjoint windows' do
    it 'sells freely when the occupancy windows do not overlap' do
      perf_a = performance_at(prod_a, '14:00')  # busy 13:30 - 16:30
      perf_b = performance_at(prod_b, '20:00')  # busy 19:30 - 22:30
      shadow_a = shadow_for(prod_a)
      shadow_b = shadow_for(prod_b)
      allocate(shadow_a, perf_a)
      allocate(shadow_b, perf_b)

      sell(perf_a, shadow_a, 2)

      expect(build_order(perf_b, shadow_b, 2)).to be_valid
    end
  end

  describe 'statuses that give devices back' do
    # Regression guard: if this validation ran on every status, shrinking a pool
    # below current usage would make it impossible to refund or cancel the orders
    # that are over the new limit.
    it 'never blocks a refund or cancellation after the pool is shrunk' do
      perf = performance_at(prod_a, '14:00')
      shadow = shadow_for(prod_a)
      allocate(shadow, perf)
      order = sell(perf, shadow, 2)

      resource.update!(quantity: 1)
      expect(resource.remaining_for(perf)).to eq(-1)

      # Reloaded so the validation sees the shrunk pool, not a memoized copy.
      fresh = TicketOrder.find(order.id)
      %w[Refunded Canceled Unclaimed Exchanged Releasing].each do |status|
        fresh.status = status
        expect(fresh).to be_valid
      end
    end

    it 'still blocks a FULFILLED order that asks for more than the shrunk pool' do
      perf = performance_at(prod_a, '14:00')
      shadow = shadow_for(prod_a)
      allocate(shadow, perf)
      order = sell(perf, shadow, 2)
      resource.update!(quantity: 1)

      # FULFILLED occupies the pool, and exclude_order means the order is not
      # blocked by its own devices -- it simply asks for more than now exist.
      fresh = TicketOrder.find(order.id)
      fresh.status = Order::FULFILLED
      expect(fresh).not_to be_valid
      expect(fresh.errors[:base].join).to match(/only 1 .* available/)
    end
  end

  describe 'non-resourced classes' do
    it 'is unaffected by the resourced validation' do
      perf = performance_at(prod_a, '14:00')
      plain = FactoryBot.create(:ticket_class, production: prod_a, class_code: 'PLAINX',
                                               holds_seats: true, ticket_price: 10, ticketing_fee: 0)
      allocate(plain, perf)

      expect(build_order(perf, plain, 2)).to be_valid
    end
  end

  describe 'TicketClass#number_left for a shadow class' do
    let(:perf) { performance_at(prod_a, '14:00') }
    let(:shadow) { shadow_for(prod_a) }

    it 'is capped by the pool when the pool is smaller than the allocation limit' do
      allocate(shadow, perf, ticket_limit: 10)

      expect(shadow.number_left(perf)).to eq(2)
    end

    it 'is capped by the allocation limit when that is smaller than the pool' do
      allocate(shadow, perf, ticket_limit: 1)

      expect(shadow.number_left(perf)).to eq(1)
    end

    it 'is the bare pool when the allocation carries no ticket_limit' do
      allocate(shadow, perf, ticket_limit: nil)
      sell(perf, shadow, 1)

      expect(shadow.number_left(perf)).to eq(1)
    end

    it 'is not capped by remaining seats, because devices are not seats' do
      allocate(shadow, perf)
      # Drain the house with an ordinary seat-holding class.
      seat_class = FactoryBot.create(:ticket_class, production: prod_a, class_code: 'HOUSEX',
                                                    holds_seats: true, ticket_price: 10, ticketing_fee: 0)
      allocate(seat_class, perf)
      sell(perf, seat_class, prod_a.capacity)

      expect(perf.reload.number_of_seats_left).to be <= 0
      expect(shadow.number_left(perf)).to eq(2)
    end

    it 'forwards exclude_order so an order being edited is not blocked by itself' do
      allocate(shadow, perf)
      order = sell(perf, shadow, 2)

      expect(shadow.number_left(perf)).to eq(0)
      expect(shadow.number_left(perf, order)).to eq(2)
    end

    it 'reports resource_available? for the sale surfaces' do
      allocate(shadow, perf)
      expect(shadow.resource_available?(perf)).to be true

      order = sell(perf, shadow, 2)
      expect(shadow.resource_available?(perf)).to be false
      expect(shadow.resource_available?(perf, order)).to be true
    end
  end

  describe 'shadow rows are read-only outside the sync path' do
    # Freshly loaded, as any other code path would see it: synced_from_resource
    # is per-object and is only ever set by the sync path itself.
    let(:shadow) { TicketClass.find(shadow_for(prod_a).id) }

    it 'rejects a manual attribute change' do
      shadow.class_name = 'Hand edited'

      expect(shadow).not_to be_valid
      expect(shadow.errors[:base].join).to match(/managed globally/)
    end

    it 'allows a no-op save' do
      expect(shadow.save).to be true
    end

    it 'allows the change when it comes from the sync path' do
      shadow.synced_from_resource = true
      shadow.class_name = 'Renamed by the resource'

      expect(shadow.save).to be true
    end

    it 'refuses a manual destroy' do
      expect { shadow.destroy }.to raise_error(UncaughtThrowError)
      expect(TicketClass.find_by(id: shadow.id)).to be_present
    end
  end
end
