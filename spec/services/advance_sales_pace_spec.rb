# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdvanceSalesPace, type: :service do
  let(:theater)    { FactoryBot.create(:theater) }
  let(:production) { FactoryBot.create(:production, theater: theater, capacity: 100) }

  def curve_row(lead_days:, tickets:, performance_id: 1)
    AdvanceSalesRows::Row.new(performance_id: performance_id, production_id: 1, theater_id: theater.id,
                              season: production.season - 1, segment: 'single', lead_days: lead_days,
                              tickets: tickets)
  end

  # 1,000 tickets: 50 at 60 days out, 450 at 10, 500 on the day, so
  # share_at(7) is 0.5 and share_at(30) is 0.05 (under the projectable minimum).
  def full_curve(source)
    AdvanceSalesCurve.from_rows([curve_row(lead_days: 60, tickets: 50),
                                 curve_row(lead_days: 10, tickets: 450),
                                 curve_row(lead_days: 0, tickets: 500)], source: source)
  end

  def thin_curve(source)
    AdvanceSalesCurve.from_rows([curve_row(lead_days: 10, tickets: 999)], source: source)
  end

  # A ticket bought by as_of has lead_days >= days out, so the default sits
  # beyond every days-out used here; show day counts only lead_days >= 1.
  def sold_row(performance, tickets, lead_days: 60)
    AdvanceSalesRows::Row.new(performance_id: performance.id, production_id: production.id, theater_id: theater.id,
                              season: production.season, segment: 'single', lead_days: lead_days, tickets: tickets)
  end

  # Distinct hours keep same-date performances clear of the uniqueness check.
  def make_performance(date, status: Performance::ACTIVE, hour: 19, of: production)
    FactoryBot.create(:performance, production: of, performance_date: date, status: status,
                                    performance_time: Time.local(date.year, date.month, date.day, hour, 30))
  end

  def stub_sold(rows)
    allow(AdvanceSalesRows).to receive(:fetch)
      .with(production_ids: [production.id], from_date: Date.current)
      .and_return(rows)
  end

  context 'with stubbed curves' do
    let(:theater_curve) { full_curve(:theater) }
    let(:building_curve) { full_curve(:building) }

    before do
      allow(AdvanceSalesCurve).to receive(:for_theater).and_return(theater_curve)
      allow(AdvanceSalesCurve).to receive(:for_building).and_return(building_curve)
    end

    it 'projects the final count from the theater curve at the same days out' do
      performance = make_performance(Date.current + 7.days)
      stub_sold([sold_row(performance, 12), sold_row(performance, 8)])

      reading = described_class.for_productions([production])[performance.id]

      expect(reading).to have_attributes(performance_id: performance.id, days_out: 7, sold: 20, typical_share: 0.5,
                                         projected_final: 40, capacity: 100, source: :theater)
      expect(reading.projected_pct_of_capacity).to be_within(1e-9).of(0.4)
      expect(AdvanceSalesCurve).not_to have_received(:for_building)
    end

    it 'says too early when the typical share is under the minimum' do
      performance = make_performance(Date.current + 30.days)
      stub_sold([sold_row(performance, 5)])

      reading = described_class.for_productions([production])[performance.id]

      expect(reading.days_out).to eq(30)
      expect(reading.sold).to eq(5)
      expect(reading.typical_share).to be_within(1e-9).of(0.05)
      expect(reading.projected_final).to be_nil
      expect(reading.projected_pct_of_capacity).to be_nil
    end

    it 'includes a performance that has sold nothing' do
      performance = make_performance(Date.current + 7.days)
      stub_sold([])

      reading = described_class.for_productions([production])[performance.id]

      expect(reading).to have_attributes(sold: 0, projected_final: 0, projected_pct_of_capacity: 0.0)
    end

    it 'leaves the percent of capacity nil when the production has no capacity' do
      production.update_column(:capacity, 0)
      performance = make_performance(Date.current + 7.days)
      stub_sold([sold_row(performance, 20)])

      reading = described_class.for_productions([production])[performance.id]

      expect(reading.projected_final).to eq(40)
      expect(reading.projected_pct_of_capacity).to be_nil
    end

    it 'uses only seasons before the production season' do
      make_performance(Date.current + 7.days)
      stub_sold([])

      described_class.for_productions([production])

      expect(AdvanceSalesCurve).to have_received(:for_theater)
        .with(production.theater, before_season: production.season)
    end

    context 'when the theater has too little history' do
      let(:theater_curve) { thin_curve(:theater) }

      it 'falls back to the building curve' do
        performance = make_performance(Date.current + 7.days)
        stub_sold([sold_row(performance, 20)])

        reading = described_class.for_productions([production])[performance.id]

        expect(AdvanceSalesCurve).to have_received(:for_building).with(before_season: production.season)
        expect(reading).to have_attributes(source: :building, projected_final: 40)
      end
    end

    context 'when neither curve has enough history' do
      let(:theater_curve) { thin_curve(:theater) }
      let(:building_curve) { thin_curve(:building) }

      it 'returns no readings' do
        make_performance(Date.current + 7.days)
        stub_sold([])

        expect(described_class.for_productions([production])).to eq({})
      end
    end

    it 'returns no readings when the production has no season' do
      make_performance(Date.current + 7.days)
      production.update_column(:season, nil)

      expect(described_class.for_productions([production])).to eq({})
      expect(AdvanceSalesCurve).not_to have_received(:for_theater)
    end

    it 'returns no readings, and queries no curve or sales, when sales are recorded externally' do
      make_performance(Date.current + 7.days)
      production.update_column(:sales_recorded_externally, true)
      allow(AdvanceSalesRows).to receive(:fetch)

      expect(described_class.for_productions([production])).to eq({})
      expect(AdvanceSalesCurve).not_to have_received(:for_theater)
      expect(AdvanceSalesCurve).not_to have_received(:for_building)
      expect(AdvanceSalesRows).not_to have_received(:fetch)
    end

    it 'returns no readings when there are no upcoming performances' do
      make_performance(Date.current - 1.day)

      expect(described_class.for_productions([production])).to eq({})
      expect(AdvanceSalesCurve).not_to have_received(:for_theater)
    end

    it 'skips past and inactive performances' do
      upcoming = make_performance(Date.current + 7.days)
      today    = make_performance(Date.current)
      make_performance(Date.current - 1.day)
      make_performance(Date.current + 7.days, status: Performance::INACTIVE, hour: 14)
      make_performance(Date.current + 7.days, status: Performance::PRIVATE, hour: 10)
      stub_sold([])

      readings = described_class.for_productions([production])

      expect(readings.keys).to contain_exactly(upcoming.id, today.id)
      expect(readings[today.id].days_out).to eq(0)
    end

    it 'measures days out from as_of' do
      performance = make_performance(Date.current + 37.days)
      as_of = Date.current + 30.days
      allow(AdvanceSalesRows).to receive(:fetch)
        .with(production_ids: [production.id], from_date: as_of)
        .and_return([sold_row(performance, 20)])

      reading = described_class.for_productions([production], as_of: as_of)[performance.id]

      expect(reading).to have_attributes(days_out: 7, projected_final: 40)
    end

    context 'with productions in two theaters' do
      let(:other_theater)    { FactoryBot.create(:theater) }
      let(:other_production) { FactoryBot.create(:production, theater: other_theater, capacity: 200) }

      before do
        allow(AdvanceSalesCurve).to receive(:for_theater)
          .with(other_theater, before_season: other_production.season).and_return(thin_curve(:theater))
      end

      it 'reads every production in one call, each with its own curve and capacity' do
        ours   = make_performance(Date.current + 7.days)
        theirs = make_performance(Date.current + 7.days, of: other_production)
        allow(AdvanceSalesRows).to receive(:fetch).and_return([sold_row(ours, 20), sold_row(theirs, 10)])

        readings = described_class.for_productions([production, other_production])

        expect(readings[ours.id]).to have_attributes(source: :theater, sold: 20, projected_final: 40, capacity: 100)
        expect(readings[theirs.id]).to have_attributes(source: :building, sold: 10, projected_final: 20,
                                                       capacity: 200)
      end

      it 'fetches sales once for the whole batch' do
        make_performance(Date.current + 7.days)
        make_performance(Date.current + 8.days, of: other_production)
        allow(AdvanceSalesRows).to receive(:fetch).and_return([])

        described_class.for_productions(Production.where(id: [production.id, other_production.id]))

        expect(AdvanceSalesRows).to have_received(:fetch).once
        expect(AdvanceSalesRows).to have_received(:fetch)
          .with(production_ids: contain_exactly(production.id, other_production.id), from_date: Date.current)
      end
    end

    it 'computes a shared curve once for productions of the same theater and season' do
      sibling = FactoryBot.create(:production, theater: theater, capacity: 100, season: production.season)
      make_performance(Date.current + 7.days)
      make_performance(Date.current + 8.days, of: sibling)
      allow(AdvanceSalesRows).to receive(:fetch).and_return([])

      readings = described_class.for_productions([production, sibling])

      expect(readings.size).to eq(2)
      expect(AdvanceSalesCurve).to have_received(:for_theater).once
    end

    context 'with a curve that has 80% in hand the day before' do
      # 1,000 tickets: 800 bought 3 days out, 200 on the day, so share_at(1)
      # and share_at(3) are 0.8 and share_at(0) is 1.0.
      let(:theater_curve) do
        AdvanceSalesCurve.from_rows([curve_row(lead_days: 3, tickets: 800),
                                     curve_row(lead_days: 0, tickets: 200)], source: :theater)
      end

      it 'projects show day from the tickets bought before today and the day-before share' do
        performance = make_performance(Date.current)
        stub_sold([sold_row(performance, 15, lead_days: 4), sold_row(performance, 4, lead_days: 1),
                   sold_row(performance, 6, lead_days: 0)])

        reading = described_class.for_productions([production])[performance.id]

        expect(theater_curve.share_at(0)).to eq(1.0)
        expect(reading).to have_attributes(days_out: 0, sold: 19, typical_share: 0.8,
                                           projected_final: (19 / 0.8).round)
      end

      it 'counts every ticket sold so far for a performance days away' do
        performance = make_performance(Date.current + 3.days)
        stub_sold([sold_row(performance, 15, lead_days: 4), sold_row(performance, 5, lead_days: 3)])

        reading = described_class.for_productions([production])[performance.id]

        expect(reading).to have_attributes(days_out: 3, sold: 20, typical_share: 0.8, projected_final: 25)
      end
    end

    describe '.for_performance' do
      def stub_sold_for(performance, rows)
        allow(AdvanceSalesRows).to receive(:fetch)
          .with(production_ids: [production.id], performance_ids: [performance.id], from_date: Date.current)
          .and_return(rows)
      end

      it 'returns that performance\'s reading alone' do
        performance = make_performance(Date.current + 7.days)
        make_performance(Date.current + 8.days)
        stub_sold_for(performance, [sold_row(performance, 20)])

        reading = described_class.for_performance(performance)

        expect(reading).to have_attributes(performance_id: performance.id, days_out: 7, sold: 20,
                                           projected_final: 40, source: :theater)
      end

      it 'restricts the sales query to that performance' do
        performance = make_performance(Date.current + 7.days)
        stub_sold_for(performance, [])

        described_class.for_performance(performance)

        expect(AdvanceSalesRows).to have_received(:fetch)
          .with(production_ids: [production.id], performance_ids: [performance.id], from_date: Date.current)
      end

      it 'returns nil for a performance of an externally recorded production' do
        performance = make_performance(Date.current + 7.days)
        production.update_column(:sales_recorded_externally, true)
        allow(AdvanceSalesRows).to receive(:fetch)

        expect(described_class.for_performance(performance.reload)).to be_nil
        expect(AdvanceSalesRows).not_to have_received(:fetch)
      end

      it 'returns nil for a performance that is not upcoming' do
        performance = make_performance(Date.current - 1.day)
        allow(AdvanceSalesRows).to receive(:fetch)

        expect(described_class.for_performance(performance)).to be_nil
        expect(AdvanceSalesRows).not_to have_received(:fetch)
      end

      it 'returns nil for a performance that is not Active' do
        performance = make_performance(Date.current + 7.days, status: Performance::PRIVATE)
        allow(AdvanceSalesRows).to receive(:fetch)

        expect(described_class.for_performance(performance)).to be_nil
      end
    end

    it 'skips an externally recorded production but reads the rest of the batch' do
      performance = make_performance(Date.current + 7.days)
      external = FactoryBot.create(:production, theater: theater, capacity: 100, sales_recorded_externally: true)
      make_performance(Date.current + 7.days, of: external)
      stub_sold([sold_row(performance, 20)])

      readings = described_class.for_productions([production, external])

      expect(readings.keys).to contain_exactly(performance.id)
    end
  end

  context 'with real sales' do
    let(:venue) { FactoryBot.create(:venue) }

    def next_seq
      @seq = (@seq || 0) + 1
    end

    def make_production(season:)
      n = next_seq
      Production.create!(
        name: "Pace Prod #{n}", production_code: "PC#{n.to_s.rjust(4, '0')}", capacity: 100,
        opening_at: Date.current, first_preview_at: Date.current, press_opening_at: Date.current,
        closing_at: Date.current + 90.days, season: season, status: Production::ACTIVE,
        theater: theater, venue: venue
      )
    end

    # Unique class codes sidestep the ticket_class factory's find_or_create.
    def make_ticket_class(production)
      code = "PT#{next_seq.to_s.rjust(4, '0')}"
      TicketClass.create!(
        production: production, class_code: code, class_name: "Class #{code}", ticket_type: 'Fixed',
        ticket_price: 25.0, ticketing_fee: 0.0, complimentary: false, holds_seats: true,
        web_visible: true, auto_attach: false, software_managed: false
      )
    end

    def make_real_performance(production, on:)
      n = next_seq
      Performance.create!(
        performance_code: "#{production.production_code}#{(n % 100).to_s.rjust(2, '0')}", production: production,
        performance_date: on, performance_time: Time.zone.local(on.year, on.month, on.day, 19, 30),
        status: Performance::ACTIVE
      )
    end

    def sell(performance, tickets:, bought_at:)
      ticket_class = performance.production.ticket_classes.find_by(holds_seats: true, complimentary: false) ||
                     make_ticket_class(performance.production)
      order = TicketOrder.create!(status: Order::NEW, performance: performance, address: FactoryBot.create(:address),
                                  payment_type: FactoryBot.create(:cash_payment_type))
      TicketLineItem.create!(order: order, ticket_class: ticket_class, ticket_count: tickets)
      order.update_columns(status: Order::PROCESSED, created_at: bought_at)
      order
    end

    def days_before(date, days)
      day = date - days
      Time.zone.local(day.year, day.month, day.day, 12, 0)
    end

    it 'projects from the theater history and counts tickets sold so far' do
      current = make_production(season: 2026)
      earlier = make_production(season: 2025)
      past_show = make_real_performance(earlier, on: Date.current - 20.days)
      sell(past_show, tickets: 1000, bought_at: days_before(past_show.performance_date, 10))

      soon = make_real_performance(current, on: Date.current + 5.days)
      later = make_real_performance(current, on: Date.current + 20.days)
      sell(soon, tickets: 3, bought_at: days_before(Date.current, 1))
      sell(soon, tickets: 2, bought_at: days_before(Date.current, 0))

      readings = described_class.for_productions([current])
      curve = AdvanceSalesCurve.for_theater(theater, before_season: 2026)

      expect(readings.keys).to contain_exactly(soon.id, later.id)
      expect(readings[soon.id]).to have_attributes(sold: 5, days_out: 5, source: :theater,
                                                   typical_share: curve.share_at(5), projected_final: 5,
                                                   capacity: 100, projected_pct_of_capacity: 0.05)
      expect(readings[later.id]).to have_attributes(sold: 0, days_out: 20, typical_share: curve.share_at(20),
                                                    projected_final: nil, projected_pct_of_capacity: nil)
      expect(curve.share_at(5)).to eq(1.0)
      expect(curve.share_at(20)).to eq(0.0)
    end
  end
end
