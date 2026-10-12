# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdvanceSalesCurve, type: :service do
  def row(lead_days:, tickets:, performance_id: 1, segment: 'single')
    AdvanceSalesRows::Row.new(performance_id: performance_id, production_id: 1, theater_id: 1, season: 2025,
                              segment: segment, lead_days: lead_days, tickets: tickets)
  end

  # 10 tickets over two performances: 4 bought 30 days out, 3 at 7, 2 at 1, 1 on the day.
  let(:rows) do
    [row(lead_days: 30, tickets: 4), row(lead_days: 7, tickets: 3, performance_id: 2),
     row(lead_days: 1, tickets: 2), row(lead_days: 0, tickets: 1, performance_id: 2)]
  end
  let(:curve) { described_class.from_rows(rows) }

  describe 'from rows' do
    it 'reports the share of tickets in hand at each threshold' do
      table = curve.thresholds_table
      expect(table.keys).to eq(described_class::THRESHOLDS)
      expect(table).to include(60 => 0.0, 45 => 0.0, 30 => 0.4, 21 => 0.4, 14 => 0.4, 10 => 0.4,
                               7 => 0.7, 5 => 0.7, 3 => 0.7, 2 => 0.7, 1 => 0.9, 0 => 1.0)
    end

    it 'is fully in hand on the day and has nothing in hand beyond the earliest sale' do
      expect(curve.share_at(0)).to eq(1.0)
      expect(curve.share_at(30)).to eq(0.4)
      expect(curve.share_at(31)).to eq(0.0)
      expect(curve.share_at(365)).to eq(0.0)
    end

    it 'reports the same-day share' do
      expect(curve.same_day_share).to eq(0.1)
    end

    it 'averages tickets over performances with sales' do
      expect(curve.tickets).to eq(10)
      expect(curve.performance_count).to eq(2)
      expect(curve.tickets_per_performance).to eq(5.0)
    end

    it 'is empty with no rows' do
      empty = described_class.from_rows([])
      expect(empty).to be_empty
      expect(empty.share_at(0)).to be_nil
      expect(empty.same_day_share).to be_nil
      expect(empty.tickets_per_performance).to be_nil
      expect(empty.thresholds_table.values.uniq).to eq([nil])
    end
  end

  context 'from the database' do
    let(:venue) { FactoryBot.create(:venue) }
    let(:theater) { FactoryBot.create(:theater) }
    let(:show_date) { Date.current + 30.days }

    def next_seq
      @seq = (@seq || 0) + 1
    end

    def make_performance(theater, season:)
      n = next_seq
      production = Production.create!(
        name: "Curve Prod #{n}", production_code: "CV#{n.to_s.rjust(4, '0')}", capacity: 100,
        opening_at: Date.current, first_preview_at: Date.current, press_opening_at: Date.current,
        closing_at: Date.current + 90.days, season: season, status: Production::ACTIVE, theater: theater, venue: venue
      )
      TicketClass.create!(production: production, class_code: "CC#{n.to_s.rjust(4, '0')}", class_name: "Class #{n}",
                          ticket_type: 'Fixed', ticket_price: 25.0, ticketing_fee: 0.0, complimentary: false,
                          holds_seats: true, web_visible: true, auto_attach: false, software_managed: false)
      Performance.create!(performance_code: "#{production.production_code}01", production: production,
                          performance_date: show_date, status: Performance::PERFORMANCE_STATUSES.first,
                          performance_time: Time.zone.local(show_date.year, show_date.month, show_date.day, 19, 30))
    end

    # created_at as a naive Central wall-clock string (see advance_sales_rows_spec).
    def sell(performance, tickets:, days_before:)
      order = TicketOrder.create!(status: Order::NEW, performance: performance, address: FactoryBot.create(:address),
                                  payment_type: FactoryBot.create(:cash_payment_type))
      TicketLineItem.create!(order: order, ticket_class: performance.production.ticket_classes.first,
                             ticket_count: tickets)
      bought_on = show_date - days_before
      order.update_columns(status: Order::PROCESSED, created_at: "#{bought_on.iso8601} 12:00:00")
      order
    end

    # A flex pass whose offer is tied to a theater: a subscription pass.
    def pay_with_subscription(order, tickets:)
      offer = FactoryBot.create(:flex_pass_offer, theater: order.performance.production.theater)
      flex_pass = FactoryBot.create(:flex_pass_order, flex_pass_offer: offer).flex_pass
      FactoryBot.create(:flex_pass_payment, order: order, flex_pass: flex_pass, number_of_tickets: tickets)
    end

    describe '.for_theater' do
      before do
        sell(make_performance(theater, season: 2023), tickets: 3, days_before: 20)
        pay_with_subscription(sell(make_performance(theater, season: 2024), tickets: 1, days_before: 2), tickets: 1)
        sell(make_performance(theater, season: 2025), tickets: 50, days_before: 0)
        sell(make_performance(FactoryBot.create(:theater), season: 2024), tickets: 50, days_before: 60)
      end

      it 'uses only earlier seasons of that theater' do
        result = described_class.for_theater(theater, before_season: 2025)
        expect(result.source).to eq(:theater)
        expect(result.tickets).to eq(4)
        expect(result.performance_count).to eq(2)
        expect(result.share_at(20)).to eq(0.75)
        expect(result.share_at(21)).to eq(0.0)
      end

      it 'restricts to one segment when asked' do
        expect(described_class.for_theater(theater, before_season: 2025, segment: 'single').tickets).to eq(3)
        pass = described_class.for_theater(theater, before_season: 2025, segment: 'pass')
        expect(pass.tickets).to eq(1)
        expect(pass.share_at(2)).to eq(1.0)
        expect(pass.share_at(3)).to eq(0.0)
      end
    end

    describe '.for_building' do
      it 'pools every in-house theater and leaves external ones out' do
        sell(make_performance(theater, season: 2024), tickets: 2, days_before: 10)
        sell(make_performance(FactoryBot.create(:theater), season: 2024), tickets: 2, days_before: 0)
        external = FactoryBot.create(:theater, sales_recorded_externally: true)
        sell(make_performance(external, season: 2024), tickets: 40, days_before: 90)

        result = described_class.for_building(before_season: 2025)
        expect(result.source).to eq(:building)
        expect(result.tickets).to eq(4)
        expect(result.performance_count).to eq(2)
        expect(result.share_at(10)).to eq(0.5)
        expect(result.share_at(11)).to eq(0.0)
      end
    end

    describe 'caching' do
      let(:store) { ActiveSupport::Cache::MemoryStore.new }

      before do
        allow(Rails).to receive(:cache).and_return(store)
        sell(make_performance(theater, season: 2024), tickets: 2, days_before: 10)
      end

      it 'caches a theater curve per season and segment' do
        allow(AdvanceSalesRows).to receive(:fetch).and_call_original

        first = described_class.for_theater(theater, before_season: 2025)
        second = described_class.for_theater(theater, before_season: 2025)
        expect(AdvanceSalesRows).to have_received(:fetch).once
        expect(second.tickets).to eq(first.tickets)
        expect(store.exist?("advance_sales_curve/v1/theater/#{theater.id}/before/2025/both")).to be(true)

        described_class.for_theater(theater, before_season: 2026)
        described_class.for_theater(theater, before_season: 2025, segment: 'single')
        expect(AdvanceSalesRows).to have_received(:fetch).exactly(3).times
      end

      it 'caches the building curve' do
        allow(AdvanceSalesRows).to receive(:fetch).and_call_original

        2.times { described_class.for_building(before_season: 2025) }
        expect(AdvanceSalesRows).to have_received(:fetch).once
        expect(store.exist?('advance_sales_curve/v1/building/before/2025/both')).to be(true)
      end
    end

    it 'raises for an unknown segment' do
      expect { described_class.for_theater(theater, before_season: 2025, segment: 'comp') }
        .to raise_error(ArgumentError, /unknown segment "comp"/)
      expect { described_class.for_building(before_season: 2025, segment: 'members') }
        .to raise_error(ArgumentError, /unknown segment/)
    end
  end
end
