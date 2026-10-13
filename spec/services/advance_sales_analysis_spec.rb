# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdvanceSalesAnalysis, type: :service do
  let(:venue)   { FactoryBot.create(:venue) }
  let(:theater) { FactoryBot.create(:theater, name: 'AS Middle Theater') }
  # Past by default so series are finished; the in-progress examples date performances from today.
  let(:run_start) { Date.current - 120.days }

  def next_seq
    @seq = (@seq || 0) + 1
  end

  def make_production(theater:, season:, name: nil, starts_on: run_start)
    n = next_seq
    Production.create!(
      name: name || "Advance Prod #{n}", production_code: "AA#{n.to_s.rjust(4, '0')}", capacity: 100,
      opening_at: starts_on, first_preview_at: starts_on, press_opening_at: starts_on,
      closing_at: starts_on + 90.days, season: season, status: Production::ACTIVE, theater: theater, venue: venue
    )
  end

  def make_performance(production, on:)
    n = next_seq
    Performance.create!(
      performance_code: "#{production.production_code}#{(n % 100).to_s.rjust(2, '0')}", production: production,
      performance_date: on, performance_time: Time.zone.local(on.year, on.month, on.day, 19, 30),
      status: Performance::PERFORMANCE_STATUSES.first
    )
  end

  # Unique class codes sidestep the ticket_class factory's find_or_create.
  def make_ticket_class(production)
    code = "AT#{next_seq.to_s.rjust(4, '0')}"
    TicketClass.create!(
      production: production, class_code: code, class_name: "Class #{code}", ticket_type: 'Fixed',
      ticket_price: 25.0, ticketing_fee: 0.0, complimentary: false, holds_seats: true,
      web_visible: true, auto_attach: false, software_managed: false
    )
  end

  # A processed ticket order bought +days_before+ the performance (see advance_sales_rows_spec).
  def sell(performance, tickets:, days_before:)
    ticket_class = performance.production.ticket_classes.first || make_ticket_class(performance.production)
    order = TicketOrder.create!(status: Order::NEW, performance: performance, address: FactoryBot.create(:address),
                                payment_type: FactoryBot.create(:cash_payment_type))
    TicketLineItem.create!(order: order, ticket_class: ticket_class, ticket_count: tickets)
    day = performance.performance_date - days_before
    order.update_columns(status: Order::PROCESSED, created_at: Time.zone.local(day.year, day.month, day.day, 12))
    order
  end

  # A flex pass whose offer is tied to a theater: a pass.
  def pay_with_bound_flex_pass(order, tickets:)
    offer = FactoryBot.create(:flex_pass_offer, theater: order.performance.production.theater)
    flex_pass = FactoryBot.create(:flex_pass_order, flex_pass_offer: offer).flex_pass
    FactoryBot.create(:flex_pass_payment, order: order, flex_pass: flex_pass, number_of_tickets: tickets)
  end

  def row(performance, lead_days:, tickets:, segment: 'single')
    production = performance.production
    AdvanceSalesRows::Row.new(performance_id: performance.id, production_id: production.id,
                              theater_id: production.theater_id, season: production.season, segment: segment,
                              lead_days: lead_days, tickets: tickets)
  end

  def analysis(theater_ids: [theater.id], seasons: [2025], compare_by: 'season', segment: 'both',
               include_external: false)
    described_class.new(theater_ids: theater_ids, seasons: seasons, compare_by: compare_by, segment: segment,
                        include_external: include_external)
  end

  def stub_rows(*rows)
    allow(AdvanceSalesRows).to receive(:fetch).and_return(rows.flatten)
  end

  describe '#compute' do
    describe 'series' do
      it 'builds a single-ticket and a pass line per season' do
        performance = make_performance(make_production(theater: theater, season: 2025), on: run_start)
        sell(performance, tickets: 3, days_before: 10)
        pay_with_bound_flex_pass(sell(performance, tickets: 2, days_before: 1), tickets: 2)

        result = analysis.compute

        expect(result.series.map(&:label)).to eq(['2025 – single tickets', '2025 – passes'])
        expect(result.series.map(&:segment)).to eq(%w[single pass])
        expect(result.series.map(&:tickets)).to eq([3, 2])
        expect(result.series.first.curve.share_at(10)).to eq(1.0)
        expect(result.series.first.curve.share_at(11)).to eq(0.0)
        expect(result.tickets).to eq(5)
        expect(result.truncated).to be(false)
      end

      it 'builds one group per theater, ordered by theater name' do
        zeta = FactoryBot.create(:theater, name: 'AS Zeta Theater')
        alpha = FactoryBot.create(:theater, name: 'AS Alpha Theater')
        stub_rows(row(make_performance(make_production(theater: zeta, season: 2025), on: run_start),
                      lead_days: 3, tickets: 2),
                  row(make_performance(make_production(theater: alpha, season: 2025), on: run_start),
                      lead_days: 5, tickets: 1))

        result = analysis(theater_ids: [zeta.id, alpha.id], compare_by: 'theater').compute

        expect(result.series.map(&:label))
          .to eq(['AS Alpha Theater – single tickets', 'AS Zeta Theater – single tickets'])
        expect(result.series.map(&:key)).to eq([alpha.id, zeta.id])
      end

      it 'labels production groups with the production picker label' do
        older = make_production(theater: theater, season: 2024, name: 'Older Show')
        newer = make_production(theater: theater, season: 2025, name: 'Newer Show')
        stub_rows(row(make_performance(older, on: run_start), lead_days: 3, tickets: 2),
                  row(make_performance(newer, on: run_start), lead_days: 3, tickets: 2, segment: 'pass'))

        result = analysis(seasons: [2024, 2025], compare_by: 'production').compute

        expect(result.series.map(&:label)).to eq(["#{newer.picker_label} – passes",
                                                  "#{older.picker_label} – single tickets"])
        expect(newer.picker_label).to eq('2025 - Newer Show (AS Middle Theater)')
      end

      it 'keeps only the chosen segment and drops the label suffix' do
        performance = make_performance(make_production(theater: theater, season: 2025), on: run_start)
        stub_rows(row(performance, lead_days: 3, tickets: 2),
                  row(performance, lead_days: 1, tickets: 4, segment: 'pass'))

        result = analysis(segment: 'pass').compute

        expect(result.series.map { |s| [s.label, s.segment, s.tickets] }).to eq([['2025', 'pass', 4]])
      end

      it 'lists newer seasons first' do
        rows = [2023, 2025, 2024].map do |season|
          row(make_performance(make_production(theater: theater, season: season), on: run_start),
              lead_days: 2, tickets: 1)
        end
        stub_rows(rows)

        result = analysis(seasons: [2023, 2024, 2025], segment: 'single').compute

        expect(result.series.map(&:label)).to eq(%w[2025 2024 2023])
      end

      it 'skips a series with no tickets' do
        stub_rows(row(make_performance(make_production(theater: theater, season: 2025), on: run_start),
                      lead_days: 2, tickets: 3))

        result = analysis.compute

        expect(result.series.map(&:segment)).to eq(['single'])
      end

      it 'truncates past MAX_SERIES and flags it' do
        stub_const('AdvanceSalesAnalysis::MAX_SERIES', 2)
        rows = [2023, 2024, 2025].map do |season|
          row(make_performance(make_production(theater: theater, season: season), on: run_start),
              lead_days: 2, tickets: 1)
        end
        stub_rows(rows)

        result = analysis(seasons: [2023, 2024, 2025], segment: 'single').compute

        expect(result.series.map(&:label)).to eq(%w[2025 2024])
        expect(result.truncated).to be(true)
        expect(result.tickets).to eq(3)
      end

      it 'returns an empty result when theaters or seasons are empty, without querying' do
        expect(AdvanceSalesRows).not_to receive(:fetch)

        [analysis(theater_ids: []), analysis(seasons: [])].each do |empty|
          result = empty.compute
          expect(result.series).to eq([])
          expect(result.productions).to eq([])
          expect(result.tickets).to eq(0)
          expect(result.truncated).to be(false)
          expect(result.activity?).to be(false)
        end
      end
    end

    describe 'production runs' do
      let(:production) { make_production(theater: theater, season: 2025) }

      def run_for(result)
        result.productions.find { |run| run.production.id == production.id }
      end

      it 'assigns performances to run weeks from the first playing date' do
        production.update_columns(press_opening_at: run_start + 3.days, opening_at: run_start + 5.days)
        perfs = [0, 6, 7, -1].map { |offset| make_performance(production, on: run_start + offset.days) }
        stub_rows(perfs.map { |perf| row(perf, lead_days: 1, tickets: 1) })

        weeks = run_for(analysis.compute).weeks

        expect(weeks.map(&:index)).to eq([-1, 0, 1])
        expect(weeks.map(&:starts_on)).to eq([run_start - 7.days, run_start, run_start + 7.days])
        expect(weeks.map(&:performance_count)).to eq([1, 2, 1])
        expect(weeks.map(&:tickets)).to eq([1, 2, 1])
      end

      it 'falls back to the earliest performance when the production has no run dates' do
        production.update_columns(first_preview_at: nil, press_opening_at: nil, opening_at: nil)
        earliest = run_start + 3.days
        perfs = [10, 3, 4].map { |offset| make_performance(production, on: run_start + offset.days) }
        stub_rows(perfs.map { |perf| row(perf, lead_days: 1, tickets: 1) })

        weeks = run_for(analysis.compute).weeks

        expect(weeks.map(&:index)).to eq([0, 1])
        expect(weeks.first.starts_on).to eq(earliest)
        expect(weeks.map(&:performance_count)).to eq([2, 1])
      end

      it 'collapses performances more than two weeks before the start into the floor week' do
        perfs = [-8, -20, -60, -1].map { |offset| make_performance(production, on: run_start + offset.days) }
        stub_rows(perfs.map { |perf| row(perf, lead_days: 1, tickets: 1) })

        weeks = run_for(analysis.compute).weeks

        expect(weeks.map(&:index)).to eq([described_class::PRE_RUN_WEEK_FLOOR, -1])
        expect(weeks.first.starts_on).to eq(run_start - 14.days)
        expect(weeks.map(&:performance_count)).to eq([3, 1])
      end

      it 'flags performances activated after the run started as added later' do
        announced = make_performance(production, on: run_start + 1.day)
        on_the_day = make_performance(production, on: run_start + 2.days)
        extension = make_performance(production, on: run_start + 8.days)
        announced.update_column(:activated_at, Time.zone.local(2025, 1, 1, 12))
        on_the_day.update_column(:activated_at, run_start.in_time_zone + 12.hours)
        extension.update_column(:activated_at, (run_start + 5.days).in_time_zone + 12.hours)
        stub_rows([announced, on_the_day, extension].map { |perf| row(perf, lead_days: 1, tickets: 1) })

        run = run_for(analysis.compute)

        expect(run.added_later_count).to eq(1)
        expect(run.weeks.map { |week| [week.index, week.added_later_count] }).to eq([[0, 0], [1, 1]])
      end

      it 'computes average lead, same-day and over-two-week shares per week' do
        performance = make_performance(production, on: run_start + 2.days)
        sell(performance, tickets: 2, days_before: 0)
        sell(performance, tickets: 1, days_before: 14)
        sell(performance, tickets: 1, days_before: 20)

        run = run_for(analysis.compute)

        expect(run.tickets).to eq(4)
        expect(run.weeks.size).to eq(1)
        expect(run.weeks.first).to have_attributes(index: 0, tickets: 4, avg_lead_days: 8.5,
                                                   same_day_share: 0.5, over_two_weeks_share: 0.25)
      end

      it 'leaves out performances that sold nothing, and a week made only of them' do
        sold = make_performance(production, on: run_start)
        make_performance(production, on: run_start + 1.day)
        make_performance(production, on: run_start + 7.days)
        stub_rows(row(sold, lead_days: 3, tickets: 2))

        weeks = run_for(analysis.compute).weeks

        expect(weeks.map { |week| [week.index, week.performance_count, week.tickets] }).to eq([[0, 1, 2]])
      end

      it 'does not count an Inactive performance activated after the run started as added later' do
        played = make_performance(production, on: run_start + 1.day)
        withdrawn = make_performance(production, on: run_start + 8.days)
        played.update_column(:activated_at, run_start.in_time_zone - 30.days)
        withdrawn.update_columns(status: Performance::INACTIVE,
                                 activated_at: (run_start + 5.days).in_time_zone + 12.hours)
        sell(played, tickets: 2, days_before: 3)
        sell(withdrawn, tickets: 3, days_before: 1)

        run = run_for(analysis.compute)

        expect(run.added_later_count).to eq(0)
        expect(run.weeks.map { |week| [week.index, week.performance_count] }).to eq([[0, 1]])
        expect(run.tickets).to eq(2)
      end
    end

    describe 'in progress' do
      let(:production) { make_production(theater: theater, season: 2025) }

      def only(list)
        expect(list.size).to eq(1)
        list.first
      end

      it 'marks a series in progress and suffixes its label when a performance is dated today or later' do
        stub_rows(row(make_performance(production, on: Date.current - 1.day), lead_days: 3, tickets: 2),
                  row(make_performance(production, on: Date.current), lead_days: 3, tickets: 1))

        series = only(analysis(segment: 'single').compute.series)

        expect(series.in_progress?).to be(true)
        expect(series.label).to eq("2025#{described_class::IN_PROGRESS_SUFFIX}")
        expect(series.label).to eq('2025 (in progress)')
      end

      it 'puts the in-progress suffix after the segment suffix' do
        stub_rows(row(make_performance(production, on: Date.current + 3.days), lead_days: 3, tickets: 2))

        expect(analysis.compute.series.map(&:label)).to eq(['2025 – single tickets (in progress)'])
      end

      it 'leaves a series with only past performances unmarked, with the plain label' do
        stub_rows(row(make_performance(production, on: Date.current - 1.day), lead_days: 3, tickets: 2))

        series = only(analysis(segment: 'single').compute.series)

        expect(series.in_progress?).to be(false)
        expect(series.label).to eq('2025')
        expect(series).to have_attributes(performance_count: 1, upcoming_performance_count: 0)
      end

      it 'counts performances and upcoming performances per series' do
        past = [-10, -3].map { |offset| make_performance(production, on: Date.current + offset.days) }
        upcoming = make_performance(production, on: Date.current + 5.days)
        stub_rows(past.map { |perf| row(perf, lead_days: 1, tickets: 1) },
                  row(past.first, lead_days: 4, tickets: 2),
                  row(upcoming, lead_days: 2, tickets: 1))

        series = only(analysis(segment: 'single').compute.series)

        expect(series).to have_attributes(performance_count: 3, upcoming_performance_count: 1, tickets: 5)
      end

      it 'counts upcoming performances per run week and flags the run as in progress' do
        production.update_columns(first_preview_at: Date.current - 3.days, press_opening_at: Date.current - 3.days,
                                  opening_at: Date.current - 3.days)
        perfs = [-3, 0, 2, 5].map { |offset| make_performance(production, on: Date.current + offset.days) }
        stub_rows(perfs.map { |perf| row(perf, lead_days: 1, tickets: 1) })

        run = only(analysis.compute.productions)

        expect(run.in_progress?).to be(true)
        expect(run.weeks.map { |week| [week.index, week.performance_count, week.upcoming_count] })
          .to eq([[0, 3, 2], [1, 1, 1]])
      end

      it 'counts the same upcoming performances in the series and the run weeks' do
        production.update_columns(first_preview_at: Date.current - 3.days, press_opening_at: Date.current - 3.days,
                                  opening_at: Date.current - 3.days)
        sold = [-3, 1, 9].map { |offset| make_performance(production, on: Date.current + offset.days) }
        make_performance(production, on: Date.current + 2.days) # nothing sold
        sold.each { |perf| sell(perf, tickets: 1, days_before: 2) }

        result = analysis(compare_by: 'production', segment: 'single').compute
        series = only(result.series)
        run = only(result.productions)

        expect(series.upcoming_performance_count).to eq(2)
        expect(run.weeks.sum(&:upcoming_count)).to eq(series.upcoming_performance_count)
        expect(run.weeks.sum(&:performance_count)).to eq(series.performance_count)
      end

      it 'does not flag a run whose performances have all played' do
        stub_rows(row(make_performance(production, on: Date.current - 1.day), lead_days: 1, tickets: 1))

        run = only(analysis.compute.productions)

        expect(run.in_progress?).to be(false)
        expect(run.weeks.map(&:upcoming_count)).to eq([0])
      end

      it 'reports in_progress? on the result when any series is' do
        played = make_performance(make_production(theater: theater, season: 2024), on: Date.current - 30.days)
        stub_rows(row(played, lead_days: 1, tickets: 1))
        expect(analysis(seasons: [2024, 2025], segment: 'single').compute.in_progress?).to be(false)

        stub_rows(row(played, lead_days: 1, tickets: 1),
                  row(make_performance(production, on: Date.current + 1.day), lead_days: 1, tickets: 1))
        result = analysis(seasons: [2024, 2025], segment: 'single').compute

        expect(result.series.map(&:in_progress?)).to eq([true, false])
        expect(result.in_progress?).to be(true)
      end
    end

    describe 'caching' do
      let(:store) { ActiveSupport::Cache::MemoryStore.new }

      before do
        allow(Rails).to receive(:cache).and_return(store)
        allow(AdvanceSalesRows).to receive(:fetch).and_call_original
        sell(make_performance(make_production(theater: theater, season: 2025), on: run_start),
             tickets: 2, days_before: 10)
      end

      it 'caches on the filter values' do
        first = analysis.compute
        second = analysis(seasons: ['2025'], theater_ids: [theater.id.to_s]).compute
        expect(AdvanceSalesRows).to have_received(:fetch).once
        expect(second.tickets).to eq(first.tickets)

        analysis(segment: 'single').compute
        expect(AdvanceSalesRows).to have_received(:fetch).twice
      end

      it 'caches separately on different days' do
        travel_to(Time.zone.local(2026, 3, 10, 12)) { analysis.compute }
        travel_to(Time.zone.local(2026, 3, 10, 12, 30)) { analysis.compute }
        expect(AdvanceSalesRows).to have_received(:fetch).once

        travel_to(Time.zone.local(2026, 3, 11, 12)) { analysis.compute }
        expect(AdvanceSalesRows).to have_received(:fetch).twice
      end
    end
  end

  it 'raises for an unknown compare_by or segment' do
    expect { analysis(compare_by: 'venue') }.to raise_error(ArgumentError, /unknown compare_by "venue"/)
    expect { analysis(segment: 'comp') }.to raise_error(ArgumentError, /unknown segment "comp"/)
  end
end
