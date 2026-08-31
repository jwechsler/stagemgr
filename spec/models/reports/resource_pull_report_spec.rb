require 'rails_helper'

# ResourcePullReport is the staff pull sheet: for a given performance date,
# what shared equipment (a ResourcedTicketClass's device pool) needs to be
# staged, and for whom. Build technique follows
# spec/models/orders/ticket_order_resourced_spec.rb.
RSpec.describe ResourcePullReport do
  let(:venue_a) { FactoryBot.create(:venue) }
  let(:venue_b) { FactoryBot.create(:venue) }
  let(:theater) { FactoryBot.create(:theater) }
  let(:show_date) { Date.current + 30.days }

  let(:resource) do
    FactoryBot.create(:resourced_ticket_class, quantity: 5, changeover_minutes: 30,
                                               venues: [venue_a, venue_b])
  end

  let(:prod_a) { FactoryBot.create(:production, venue: venue_a, theater: theater, running_time: 90) }
  let(:prod_b) { FactoryBot.create(:production, venue: venue_b, theater: theater, running_time: 90) }

  # performance_time is a naive wall-clock TIME column; a bare (system zone)
  # Time is what stores the hour asked for here.
  def performance_at(production, time_string, date: show_date)
    FactoryBot.create(:performance, production: production,
                                    performance_date: date,
                                    performance_time: Time.parse("#{date} #{time_string}"))
  end

  def shadow_for(production, res = resource)
    tc = TicketClass.find_or_initialize_by(production_id: production.id,
                                           resourced_ticket_class_id: res.id)
    tc.synced_from_resource = true
    tc.attributes = res.shadow_attributes
    tc.save!
    tc
  end

  def allocate(shadow, performance)
    tca = TicketClassAllocation.find_or_create_by!(performance: performance, ticket_class: shadow)
    tca.update!(available: true)
    # The performance factory's auto_attach machinery may have already cached
    # ticket_class_allocations before this allocation existed.
    performance.ticket_class_allocations.reload
    tca
  end

  def build_order(performance, shadow, count, status: Order::PROCESSED, last_name: nil, first_name: nil)
    # Address#regularize! re-derives first_name/last_name FROM full_name on
    # every save, so the override has to go through full_name, not the
    # individual name columns.
    address_attrs = first_name || last_name ? { full_name: "#{first_name} #{last_name}".strip } : {}
    address = FactoryBot.create(:address, **address_attrs)
    order = TicketOrder.new(status: status, performance: performance, address: address,
                            payment_type: FactoryBot.create(:cash_payment_type))
    order.ticket_line_items << TicketLineItem.new(ticket_class: shadow, ticket_count: count)
    order.save!
    order
  end

  describe '#create' do
    it 'groups rows under their resourced ticket class' do
      perf = performance_at(prod_a, '14:00')
      shadow = shadow_for(prod_a)
      allocate(shadow, perf)
      build_order(perf, shadow, 2)

      _headers, report = described_class.new(show_date).create

      expect(report.size).to eq(1)
      expect(report.first[:resource_code]).to eq(resource.class_code)
      expect(report.first[:resource_name]).to eq(resource.class_name)
      expect(report.first[:total]).to eq(2)
    end

    it 'sorts rows by performance_code, then patron last name, then first name' do
      perf_a = performance_at(prod_a, '14:00')
      perf_b = performance_at(prod_b, '20:00')
      shadow_a = shadow_for(prod_a)
      shadow_b = shadow_for(prod_b)
      allocate(shadow_a, perf_a)
      allocate(shadow_b, perf_b)

      # Two rows on the same performance (perf_a), to prove the name tiebreak,
      # plus one row on a different performance, all built out of sort order.
      build_order(perf_b, shadow_b, 1, last_name: 'Zeta', first_name: 'Amy')
      build_order(perf_a, shadow_a, 1, last_name: 'Beta', first_name: 'Zoe')
      build_order(perf_a, shadow_a, 1, last_name: 'Alpha', first_name: 'Amy')

      _headers, report = described_class.new(show_date).create
      rows = report.first[:rows]

      expected = rows.sort_by { |r| [r[:performance_code], r[:last_name].to_s, r[:first_name].to_s] }
      expect(rows).to eq(expected)

      perf_a_rows = rows.select { |r| r[:performance_code] == perf_a.performance_code }
      expect(perf_a_rows.pluck(:last_name)).to eq(%w[Alpha Beta])
    end

    it 'excludes refunded orders and includes held orders' do
      perf = performance_at(prod_a, '14:00')
      shadow = shadow_for(prod_a)
      allocate(shadow, perf)
      refunded = build_order(perf, shadow, 1)
      refunded.update!(status: Order::REFUNDED)
      build_order(perf, shadow, 1, status: Order::HOLD)

      _headers, report = described_class.new(show_date).create

      expect(report.first[:total]).to eq(1)
    end

    it 'nets refund line items on the same order and drops orders that net to zero or less' do
      # A partial refund/split leaves a reversing (negative ticket_count) row
      # on the SAME order rather than changing its status -- the order also
      # keeps an unrelated, non-resourced ticket so it still satisfies "must
      # contain at least one ticket" once the resourced item nets to zero.
      perf = performance_at(prod_a, '14:00')
      shadow = shadow_for(prod_a)
      allocate(shadow, perf)
      keep_class = FactoryBot.create(:ticket_class, production: prod_a, class_code: 'KEEPX',
                                                    holds_seats: false, ticket_price: 10, ticketing_fee: 0)
      tca = TicketClassAllocation.find_or_create_by!(performance: perf, ticket_class: keep_class)
      tca.update!(available: true)
      perf.ticket_class_allocations.reload

      order = build_order(perf, shadow, 2)
      order.ticket_line_items << TicketLineItem.new(ticket_class: keep_class, ticket_count: 1)
      order.ticket_line_items << TicketLineItem.new(ticket_class: shadow, ticket_count: -2)
      order.save!

      _headers, report = described_class.new(show_date).create

      expect(report).to be_empty
    end

    it 'computes per-performance subtotals and a per-resource total' do
      perf_a = performance_at(prod_a, '14:00')
      perf_b = performance_at(prod_b, '20:00')
      shadow_a = shadow_for(prod_a)
      shadow_b = shadow_for(prod_b)
      allocate(shadow_a, perf_a)
      allocate(shadow_b, perf_b)

      build_order(perf_a, shadow_a, 1)
      build_order(perf_a, shadow_a, 2)
      build_order(perf_b, shadow_b, 1)

      _headers, report = described_class.new(show_date).create
      group = report.first

      expect(group[:performance_subtotals][perf_a.performance_code]).to eq(3)
      expect(group[:performance_subtotals][perf_b.performance_code]).to eq(1)
      expect(group[:total]).to eq(4)
    end

    it 'ignores line items outside the requested performance date' do
      other_date = show_date + 1.day
      perf = performance_at(prod_a, '14:00')
      other_perf = performance_at(prod_a, '14:00', date: other_date)
      shadow = shadow_for(prod_a)
      allocate(shadow, perf)
      allocate(shadow, other_perf)
      build_order(other_perf, shadow, 1)

      _headers, report = described_class.new(show_date).create

      expect(report).to be_empty
    end

    it 'ignores non-resourced ticket classes' do
      perf = performance_at(prod_a, '14:00')
      plain = FactoryBot.create(:ticket_class, production: prod_a, class_code: 'PLAINX',
                                               holds_seats: false, ticket_price: 10, ticketing_fee: 0)
      tca = TicketClassAllocation.find_or_create_by!(performance: perf, ticket_class: plain)
      tca.update!(available: true)
      perf.ticket_class_allocations.reload
      build_order(perf, plain, 2)

      _headers, report = described_class.new(show_date).create

      expect(report).to be_empty
    end

    it 'separates multiple resourced ticket classes into their own groups' do
      other_resource = FactoryBot.create(:resourced_ticket_class, quantity: 3, venues: [venue_a])
      perf = performance_at(prod_a, '14:00')
      shadow = shadow_for(prod_a)
      other_shadow = shadow_for(prod_a, other_resource)
      allocate(shadow, perf)
      allocate(other_shadow, perf)

      build_order(perf, shadow, 1)
      build_order(perf, other_shadow, 1)

      _headers, report = described_class.new(show_date).create

      expect(report.size).to eq(2)
      codes = report.pluck(:resource_code)
      expect(codes).to contain_exactly(resource.class_code, other_resource.class_code)
    end
  end
end
