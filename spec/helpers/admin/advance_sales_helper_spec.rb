# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::AdvanceSalesHelper, type: :helper do
  describe '#advance_sales_share' do
    it 'formats a share as a whole percent and nil as the empty cell' do
      expect(helper.advance_sales_share(0.426)).to eq('43%')
      expect(helper.advance_sales_share(1.0)).to eq('100%')
      expect(helper.advance_sales_share(0.0)).to eq('0%')
      expect(helper.advance_sales_share(nil)).to eq('—')
    end
  end

  describe '#advance_sales_week_label' do
    def label(index)
      helper.advance_sales_week_label(AdvanceSalesAnalysis::RunWeek.new(index: index))
    end

    it 'labels the floor, pre-run and run weeks' do
      expect(label(AdvanceSalesAnalysis::PRE_RUN_WEEK_FLOOR)).to eq('Earlier')
      expect(label(-1)).to eq('Week before')
      expect(label(0)).to eq('Week 1')
      expect(label(3)).to eq('Week 4')
    end
  end

  describe '#advance_sales_days_label' do
    it 'labels days out' do
      expect(helper.advance_sales_days_label(0)).to eq('Same day')
      expect(helper.advance_sales_days_label(14)).to eq('14d')
    end
  end

  describe '#advance_sales_bucket_label' do
    it 'labels lead-day windows' do
      expect(helper.advance_sales_bucket_label(0, 0)).to eq('Same day')
      expect(helper.advance_sales_bucket_label(1, 2)).to eq('1–2d')
      expect(helper.advance_sales_bucket_label(30, nil)).to eq('30+d')
    end
  end

  describe '#advance_sales_lead' do
    it 'shows days to one decimal place and nil as the empty cell' do
      expect(helper.advance_sales_lead(8.25)).to eq('8.3 days')
      expect(helper.advance_sales_lead(nil)).to eq('—')
    end
  end

  describe '#advance_sales_chart_data' do
    def row(lead_days:, tickets:)
      AdvanceSalesRows::Row.new(performance_id: 1, production_id: 1, theater_id: 1, season: 2025,
                                segment: 'single', lead_days: lead_days, tickets: tickets)
    end

    def series(label, rows)
      AdvanceSalesAnalysis::Series.new(key: label, label: label, segment: 'single', tickets: rows.sum(&:tickets),
                                       curve: AdvanceSalesCurve.from_rows(rows))
    end

    it 'builds one chart line per series over the thresholds with percentages' do
      early = series('2025', [row(lead_days: 30, tickets: 1), row(lead_days: 0, tickets: 2)])
      late = series('2024', [row(lead_days: 1, tickets: 1)])

      data = helper.advance_sales_chart_data([early, late])

      expect(data.pluck(:name)).to eq(%w[2025 2024])
      expect(data.first[:data].map(&:first))
        .to eq(%w[60d 45d 30d 21d 14d 10d 7d 5d 3d 2d 1d] + ['Same day'])
      expect(data.first[:data].to_h).to include('60d' => 0.0, '30d' => 33.3, '1d' => 33.3, 'Same day' => 100.0)
      expect(data.last[:data].to_h).to include('2d' => 0.0, '1d' => 100.0, 'Same day' => 100.0)
    end

    it 'dashes the chart line for an in-progress series only' do
      rows = [row(lead_days: 3, tickets: 1)]
      running = series('2026 (in progress)', rows).tap do |s|
        s.performance_count = 4
        s.upcoming_performance_count = 2
      end
      finished = series('2025', rows).tap do |s|
        s.performance_count = 4
        s.upcoming_performance_count = 0
      end

      data = helper.advance_sales_chart_data([running, finished])

      expect(data.first[:dataset]).to eq(borderDash: Admin::AdvanceSalesHelper::IN_PROGRESS_DASH)
      expect(data.last).not_to have_key(:dataset)
    end

    it 'leaves a series without performance counts undashed' do
      expect(helper.advance_sales_chart_data([series('2025', [row(lead_days: 1, tickets: 1)])]).first)
        .not_to have_key(:dataset)
    end
  end

  describe '#advance_sales_still_to_play' do
    def series(upcoming)
      AdvanceSalesAnalysis::Series.new(label: 'S', performance_count: 40, upcoming_performance_count: upcoming)
    end

    it 'reports still-to-play as "n of m" for an in-progress series and a dash otherwise' do
      expect(helper.advance_sales_still_to_play(series(3))).to eq('3 of 40')
      expect(helper.advance_sales_still_to_play(series(0))).to eq('—')
      expect(helper.advance_sales_still_to_play(AdvanceSalesAnalysis::Series.new(label: 'S'))).to eq('—')
    end
  end

  describe '#advance_sales_week_marker' do
    it 'labels a week with performances upcoming and returns nil otherwise' do
      html = helper.advance_sales_week_marker(AdvanceSalesAnalysis::RunWeek.new(index: 0, upcoming_count: 2))

      expect(html).to have_css('span.label.secondary', exact_text: '2 upcoming')
      expect(helper.advance_sales_week_marker(AdvanceSalesAnalysis::RunWeek.new(index: 0, upcoming_count: 0)))
        .to be_nil
    end
  end

  describe '#house_count_pace_cell' do
    let(:as_of) { Date.new(2026, 10, 6) }
    let(:production) { FactoryBot.build_stubbed(:production, sales_recorded_externally: false) }
    let(:performance) { FactoryBot.build_stubbed(:performance, production: production, performance_date: as_of + 7) }

    def house_count(**attrs)
      HouseCount.new(performance: performance, total_seats: 100, projected_seats: 40, pace_share: 0.5,
                     pace_sold: 20, pace_source: 'theater', pace_as_of: as_of, **attrs)
    end

    it 'shows the empty cell titled to explain it when sales are recorded externally' do
      production.sales_recorded_externally = true

      expect(helper.house_count_pace_cell(house_count))
        .to have_css('span[title="Sales recorded externally"]', exact_text: '—')
    end

    it 'shows the bare empty cell when no pace snapshot has been taken' do
      expect(helper.house_count_pace_cell(house_count(pace_as_of: nil))).to eq('—')
    end

    it 'shows the bare empty cell when the snapshot had nothing to project from' do
      expect(helper.house_count_pace_cell(house_count(pace_share: nil, projected_seats: nil))).to eq('—')
    end

    it 'says too early, with the basis in the title, when the share in hand is too small to project' do
      performance.performance_date = as_of + 30
      html = helper.house_count_pace_cell(house_count(pace_sold: 5, pace_share: 0.05, projected_seats: nil))

      expect(html).to have_css(
        'span[title="Sold 5 as of Oct 6; this house typically has 5% in hand 30 days out"]',
        exact_text: 'Too early'
      )
    end

    it 'shows the expected count alone, with the basis in the title' do
      html = helper.house_count_pace_cell(house_count(projected_seats: 1234, total_seats: 2000))

      expect(html).to have_css(
        'span[title="Sold 20 as of Oct 6; this house typically has 50% in hand 7 days out"]',
        exact_text: '~1,234'
      )
    end

    it 'shows the empty cell, titled to say so, once sold has passed the expected count' do
      html = helper.house_count_pace_cell(house_count(sold_seats: 1235, projected_seats: 1234, total_seats: 2000))

      expect(html).to have_css('span[title="Sold has already passed the expected ~1,234"]', exact_text: '—')
    end

    it 'shows the house size when demand exceeds it, with the demand in the title' do
      html = helper.house_count_pace_cell(house_count(total_seats: 104, sold_seats: 71, pace_sold: 71,
                                                      projected_seats: 124))

      expect(html).to have_css(
        'span[title="Sold 71 as of Oct 6; this house typically has 50% in hand 7 days out; ' \
        'demand ~124 exceeds the 104 seats"]',
        exact_text: '~104'
      )
    end

    it 'shows the titled empty cell, naming the capped count, once sold reaches a capped projection' do
      html = helper.house_count_pace_cell(house_count(total_seats: 104, sold_seats: 104, projected_seats: 124))

      expect(html).to have_css('span[title="Sold has already passed the expected ~104"]', exact_text: '—')
    end

    it 'still shows the expected count when sold equals it' do
      html = helper.house_count_pace_cell(house_count(sold_seats: 40))

      expect(html).to have_css('span', exact_text: '~40')
    end

    it 'describes the show-day basis in the title on the day of the show' do
      performance.performance_date = as_of
      html = helper.house_count_pace_cell(house_count(pace_sold: 19, pace_share: 0.79, projected_seats: 24,
                                                      pace_source: 'building'))

      expect(html).to have_css(
        'span[title="Sold 19 before today; this house typically has 79% in hand by show day (building-wide curve)"]',
        exact_text: '~24'
      )
    end

    it 'notes the building-wide curve in the title' do
      html = helper.house_count_pace_cell(house_count(pace_source: 'building'))

      expect(html).to have_css(
        'span[title="Sold 20 as of Oct 6; this house typically has 50% in hand 7 days out (building-wide curve)"]',
        exact_text: '~40'
      )
    end
  end
end
