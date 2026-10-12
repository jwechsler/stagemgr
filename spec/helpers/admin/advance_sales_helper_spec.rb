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
  end
end
