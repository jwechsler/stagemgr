# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdvanceSalesRows, type: :service do
  let(:theater) { FactoryBot.create(:theater) }
  let(:venue)   { FactoryBot.create(:venue) }
  let(:show_date) { Date.current + 30.days }
  let(:production) { make_production(theater: theater, season: 2025) }
  let(:performance) { make_performance(production, on: show_date) }
  let(:seat_class) { make_ticket_class(production) }

  def next_seq
    @seq = (@seq || 0) + 1
  end

  def make_production(theater:, season:)
    n = next_seq
    Production.create!(
      name: "Advance Prod #{n}", production_code: "AS#{n.to_s.rjust(4, '0')}", capacity: 100,
      opening_at: Date.current, first_preview_at: Date.current, press_opening_at: Date.current,
      closing_at: Date.current + 90.days, season: season, status: Production::ACTIVE,
      theater: theater, venue: venue
    )
  end

  # Unique class codes sidestep the ticket_class factory's find_or_create.
  def make_ticket_class(production, holds_seats: true, complimentary: false)
    code = "AC#{next_seq.to_s.rjust(4, '0')}"
    TicketClass.create!(
      production: production, class_code: code, class_name: "Class #{code}", ticket_type: 'Fixed',
      ticket_price: 25.0, ticketing_fee: 0.0, complimentary: complimentary, holds_seats: holds_seats,
      web_visible: true, auto_attach: false, software_managed: false
    )
  end

  def make_performance(production, on:)
    n = next_seq
    Performance.create!(
      performance_code: "#{production.production_code}#{(n % 100).to_s.rjust(2, '0')}", production: production, performance_date: on,
      performance_time: Time.zone.local(on.year, on.month, on.day, 19, 30), status: Performance::PERFORMANCE_STATUSES.first
    )
  end

  # A ticket order with one line item, stamped with its purchase time and status.
  # bought_at is a zoned Time; with default_timezone :local ActiveRecord stores
  # it in the process's system zone (UTC under the suite), as production does.
  def sell(performance, tickets:, bought_at:, status: Order::PROCESSED, ticket_class: nil)
    ticket_class ||= performance.production.ticket_classes.find_by(holds_seats: true, complimentary: false) ||
                     make_ticket_class(performance.production)
    order = TicketOrder.create!(status: Order::NEW, performance: performance, address: FactoryBot.create(:address),
                                payment_type: FactoryBot.create(:cash_payment_type))
    TicketLineItem.create!(order: order, ticket_class: ticket_class, ticket_count: tickets)
    order.update_columns(status: status, created_at: bought_at)
    order
  end

  # The child order replacing +source+; the source keeps no line items, as in production data.
  def exchange(source, tickets:, bought_at:, link: :exchange_source_id, source_status: Order::EXCHANGED)
    child = sell(source.performance, tickets: tickets, bought_at: bought_at)
    child.update_columns(link => source.id)
    TicketLineItem.where(order_id: source.id).destroy_all
    source.update_columns(status: source_status)
    child
  end

  def pay_with_membership(order, tickets:)
    membership = FactoryBot.create(:membership, member_code: "ASMEM#{next_seq}")
    FactoryBot.create(:membership_payment, order: order, membership: membership, number_of_tickets: tickets)
  end

  # The offer's theater/festival is set explicitly: both nil is a building-wide pass.
  def pay_with_flex_pass(order, tickets:, theater: nil, festival: nil)
    offer = FactoryBot.create(:flex_pass_offer, theater: theater, festival: festival)
    flex_pass = FactoryBot.create(:flex_pass_order, flex_pass_offer: offer).flex_pass
    FactoryBot.create(:flex_pass_payment, order: order, flex_pass: flex_pass, number_of_tickets: tickets)
  end

  def bought(days_before, hour: 12, min: 0)
    day = show_date - days_before
    Time.zone.local(day.year, day.month, day.day, hour, min)
  end

  def tickets_by_lead(rows)
    rows.each_with_object(Hash.new(0)) { |r, h| h[r.lead_days] += r.tickets }
  end

  def total(rows)
    rows.sum(&:tickets)
  end

  describe '.fetch' do
    it 'counts seat-holding non-comp tickets on Processed, Fulfilled and Unclaimed orders' do
      sell(performance, tickets: 2, bought_at: bought(10), status: Order::PROCESSED)
      sell(performance, tickets: 3, bought_at: bought(5), status: Order::FULFILLED)
      sell(performance, tickets: 4, bought_at: bought(0), status: Order::UNCLAIMED)

      rows = described_class.fetch
      expect(tickets_by_lead(rows)).to eq(10 => 2, 5 => 3, 0 => 4)
      expect(rows.map(&:performance_id).uniq).to eq([performance.id])
      expect(rows.first).to have_attributes(production_id: production.id, theater_id: theater.id,
                                            season: 2025, segment: 'single')
    end

    it 'excludes complimentary ticket classes' do
      sell(performance, tickets: 2, bought_at: bought(3), ticket_class: make_ticket_class(production, complimentary: true))
      sell(performance, tickets: 1, bought_at: bought(3), ticket_class: seat_class)

      expect(total(described_class.fetch)).to eq(1)
    end

    it 'excludes ticket classes that do not hold seats' do
      sell(performance, tickets: 2, bought_at: bought(3), ticket_class: make_ticket_class(production, holds_seats: false))
      sell(performance, tickets: 1, bought_at: bought(3), ticket_class: seat_class)

      expect(total(described_class.fetch)).to eq(1)
    end

    it 'excludes Hold, New, Canceled, Refunded, Exchanged and Split orders' do
      [Order::HOLD, Order::NEW, Order::CANCELED, Order::REFUNDED, Order::EXCHANGED, Order::SPLIT].each do |status|
        sell(performance, tickets: 5, bought_at: bought(4), status: status, ticket_class: seat_class)
      end
      sell(performance, tickets: 1, bought_at: bought(4), ticket_class: seat_class)

      expect(total(described_class.fetch)).to eq(1)
    end

    it 'dates an exchanged order from the original purchase' do
      original = sell(performance, tickets: 2, bought_at: bought(20), ticket_class: seat_class)
      exchange(original, tickets: 2, bought_at: bought(2))

      expect(tickets_by_lead(described_class.fetch)).to eq(20 => 2)
    end

    it 'dates a two-level exchange from the root purchase' do
      original = sell(performance, tickets: 2, bought_at: bought(25), ticket_class: seat_class)
      middle = exchange(original, tickets: 2, bought_at: bought(10))
      exchange(middle, tickets: 2, bought_at: bought(1))

      expect(tickets_by_lead(described_class.fetch)).to eq(25 => 2)
    end

    it 'dates a split order from the original purchase' do
      original = sell(performance, tickets: 3, bought_at: bought(14), ticket_class: seat_class)
      exchange(original, tickets: 1, bought_at: bought(3), link: :split_source_id, source_status: Order::SPLIT)
      exchange(original, tickets: 2, bought_at: bought(3), link: :split_source_id, source_status: Order::SPLIT)

      expect(tickets_by_lead(described_class.fetch)).to eq(14 => 3)
    end

    it 'counts a membership-paid order as single tickets' do
      order = sell(performance, tickets: 2, bought_at: bought(7), ticket_class: seat_class)
      pay_with_membership(order, tickets: 2)

      expect(described_class.fetch.map(&:segment)).to eq(['single'])
    end

    it 'classifies a flex pass tied to a theater as a pass' do
      order = sell(performance, tickets: 2, bought_at: bought(7), ticket_class: seat_class)
      pay_with_flex_pass(order, tickets: 2, theater: theater)

      expect(described_class.fetch.map(&:segment)).to eq(['pass'])
    end

    it 'classifies a flex pass tied to a festival as a pass' do
      order = sell(performance, tickets: 2, bought_at: bought(7), ticket_class: seat_class)
      pay_with_flex_pass(order, tickets: 2, festival: FactoryBot.create(:festival))

      expect(described_class.fetch.map(&:segment)).to eq(['pass'])
    end

    it 'counts a building-wide flex pass as single tickets' do
      order = sell(performance, tickets: 2, bought_at: bought(7), ticket_class: seat_class)
      pay_with_flex_pass(order, tickets: 2)

      expect(described_class.fetch.map(&:segment)).to eq(['single'])
    end

    it "classifies an exchanged pass order from the root order's payments" do
      original = sell(performance, tickets: 2, bought_at: bought(12), ticket_class: seat_class)
      pay_with_flex_pass(original, tickets: 2, theater: theater)
      child = exchange(original, tickets: 2, bought_at: bought(2))
      ExchangePayment.create!(order: child, payment_type: FactoryBot.create(:cash_payment_type), amount: 0,
                              number_of_tickets: 2)

      rows = described_class.fetch
      expect(rows.map { |r| [r.segment, r.lead_days, r.tickets] }).to eq([['pass', 12, 2]])
    end

    it 'does not count a pass payment for zero tickets as a redemption' do
      order = sell(performance, tickets: 2, bought_at: bought(7), ticket_class: seat_class)
      pay_with_flex_pass(order, tickets: 0, theater: theater)

      expect(described_class.fetch.map(&:segment)).to eq(['single'])
    end

    it 'classifies card and cash tenders as single tickets' do
      card_order = sell(performance, tickets: 2, bought_at: bought(7), ticket_class: seat_class)
      FactoryBot.create(:credit_card_payment, order: card_order, number_of_tickets: 2, amount: 50,
                                              confirmation_code: 'CONFIRMED', card_type: 'bogus', card_last_four: '1111')
      cash_order = sell(performance, tickets: 1, bought_at: bought(7), ticket_class: seat_class)
      FactoryBot.create(:cash_payment, order: cash_order, number_of_tickets: 1, amount: 25)

      rows = described_class.fetch
      expect(rows.map(&:segment).uniq).to eq(['single'])
      expect(total(rows)).to eq(3)
    end

    it 'clamps a purchase after the performance date to zero lead days' do
      sell(performance, tickets: 2, bought_at: bought(-3), ticket_class: seat_class)

      expect(tickets_by_lead(described_class.fetch)).to eq(0 => 2)
    end

    it 'uses the app zone date of the purchase' do
      sell(performance, tickets: 2, bought_at: bought(1, hour: 23, min: 30), ticket_class: seat_class)

      expect(tickets_by_lead(described_class.fetch)).to eq(1 => 2)
    end

    it 'converts from the storage zone to the app zone' do
      allow(described_class).to receive(:storage_time_zone).and_return('UTC')
      march_first = make_performance(production, on: Date.new(2026, 3, 1))
      order = sell(march_first, tickets: 2, bought_at: Time.zone.local(2026, 2, 28, 12), ticket_class: seat_class)
      # A raw UTC wall clock: 04:30 UTC is 22:30 Central on Feb 28.
      order.update_columns(created_at: '2026-03-01 04:30:00')

      expect(tickets_by_lead(described_class.fetch)).to eq(1 => 2)
    end

    # CI loads these into the MySQL service in .github/workflows/test.yml.
    it 'has the MySQL time-zone tables it needs' do
      expect(described_class.time_zone_tables_loaded?).to be true
    end

    context 'with a theater whose sales are recorded externally' do
      let(:external_theater) { FactoryBot.create(:theater, sales_recorded_externally: true) }
      let(:external_performance) do
        make_performance(make_production(theater: external_theater, season: 2025), on: show_date)
      end

      before do
        sell(performance, tickets: 1, bought_at: bought(5), ticket_class: seat_class)
        sell(external_performance, tickets: 4, bought_at: bought(5))
      end

      it 'excludes it by default' do
        expect(described_class.fetch.map(&:theater_id).uniq).to eq([theater.id])
      end

      it 'includes it when asked' do
        rows = described_class.fetch(include_external: true)
        expect(rows.map(&:theater_id)).to contain_exactly(theater.id, external_theater.id)
        expect(total(rows)).to eq(5)
      end
    end

    context 'with filters' do
      let(:other_theater) { FactoryBot.create(:theater) }
      let(:old_production) { make_production(theater: theater, season: 2023) }
      let(:other_production) { make_production(theater: other_theater, season: 2024) }
      let!(:old_performance) { make_performance(old_production, on: show_date - 10.days) }
      let!(:other_performance) { make_performance(other_production, on: show_date + 10.days) }

      before do
        sell(performance, tickets: 1, bought_at: bought(5), ticket_class: seat_class)
        sell(old_performance, tickets: 1, bought_at: bought(15))
        sell(other_performance, tickets: 1, bought_at: bought(5))
      end

      def performance_ids(**filters)
        described_class.fetch(**filters).map(&:performance_id)
      end

      it 'filters by theater_ids' do
        expect(performance_ids(theater_ids: [other_theater.id])).to eq([other_performance.id])
      end

      it 'filters by seasons' do
        expect(performance_ids(seasons: [2023, 2025])).to contain_exactly(old_performance.id, performance.id)
      end

      it 'filters by before_season' do
        expect(performance_ids(before_season: 2025)).to contain_exactly(old_performance.id, other_performance.id)
      end

      it 'filters by production_ids' do
        expect(performance_ids(production_ids: [production.id])).to eq([performance.id])
      end

      it 'filters by from_date on the performance date' do
        expect(performance_ids(from_date: show_date)).to contain_exactly(performance.id, other_performance.id)
      end

      it 'treats an empty filter array as no filter' do
        expect(performance_ids(theater_ids: [], seasons: [], production_ids: []))
          .to contain_exactly(performance.id, old_performance.id, other_performance.id)
      end
    end
  end
end
