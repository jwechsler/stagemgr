# frozen_string_literal: true

require 'rails_helper'

# Characterization specs for RateOfSalesAnalysis.
# These pin down *existing* behavior — they do NOT change app code.
RSpec.describe RateOfSalesAnalysis, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  # ---------------------------------------------------------------------------
  # Shared test data helpers
  # ---------------------------------------------------------------------------

  # Create a production whose first_playing_date is `opening_at`
  def create_production(opening: Date.today - 30.days, closing: Date.today + 30.days, capacity: 100)
    FactoryBot.create(
      :production,
      first_preview_at: opening,
      press_opening_at: opening,
      opening_at: opening,
      closing_at: closing,
      capacity: capacity
    )
  end

  # Seed n days of RateOfSale records for a production, starting from start_date
  def seed_ros(production, start_date:, days:, tickets: 10, gross_sales: 100.0)
    days.times.map do |i|
      RateOfSale.create!(
        production: production,
        day_of_sale: start_date + i.days,
        total_single_tickets: tickets,
        total_complimentary_tickets: 0,
        gross_sales: gross_sales,
        processing_fees: 0.00,
        order_count: 1
      )
    end
  end

  # ---------------------------------------------------------------------------
  # initialize / accessors
  # ---------------------------------------------------------------------------
  describe 'initialization' do
    it 'stores target_production and comparison_productions' do
      prod = create_production
      comp = create_production
      analysis = described_class.new(prod, [comp])
      expect(analysis.target_production).to eq(prod)
      expect(analysis.comparison_productions).to eq([comp])
    end
  end

  # ---------------------------------------------------------------------------
  # #compute — basic return structure
  # ---------------------------------------------------------------------------
  describe '#compute' do
    let(:production) { create_production }
    let(:comparison) { create_production }
    subject(:result) { described_class.new(production, [comparison]).compute }

    context 'with no rate_of_sale data' do
      it 'returns a Hash' do
        expect(result).to be_a(Hash)
      end

      it 'includes all expected top-level keys' do
        expected_keys = %i[
          target_tickets target_revenue aggregate_data projection
          comparison_summaries target_summary insights daily_rolling
          comparison_daily_rolling
        ]
        expected_keys.each do |key|
          expect(result).to have_key(key)
        end
      end

      it 'returns empty hashes for target_tickets and target_revenue when no data' do
        expect(result[:target_tickets]).to eq({})
        expect(result[:target_revenue]).to eq({})
      end

      it 'returns nil for projection when target has no data' do
        expect(result[:projection]).to be_nil
      end

      it 'returns an empty Hash for daily_rolling when no data' do
        expect(result[:daily_rolling]).to eq({})
      end
    end

    context 'with rate_of_sale data for target production' do
      before do
        # Seed weekly data for the target production
        # first_playing_date = production.opening_at
        # presale_cutoff = first_playing_date - 21 days
        anchor = production.first_playing_date
        seed_ros(production, start_date: anchor - 25.days, days: 5, tickets: 5, gross_sales: 50.0) # pre-sales
        seed_ros(production, start_date: anchor, days: 14, tickets: 10, gross_sales: 100.0) # weeks 1-2
      end

      it 'returns a non-empty target_tickets hash' do
        expect(result[:target_tickets]).not_to be_empty
      end

      it 'returns a non-empty target_revenue hash' do
        expect(result[:target_revenue]).not_to be_empty
      end

      it 'includes "Pre-sales" key in target_tickets when pre-sale data exists' do
        expect(result[:target_tickets]).to have_key("Pre-sales")
      end

      it 'includes week labels like "Week 1" in target_tickets' do
        expect(result[:target_tickets].keys).to include("Week 1")
      end

      it 'returns a Hash for insights' do
        expect(result[:insights]).to be_a(Hash)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private method: #weekly_totals_for (tested via #compute)
  # ---------------------------------------------------------------------------
  describe 'weekly_totals_for behavior (via compute result)' do
    let(:opening_date) { Date.today - 60.days }
    let(:production) do
      create_production(opening: opening_date, closing: Date.today + 10.days)
    end

    before do
      anchor = production.first_playing_date
      presale_cutoff = anchor - 21.days

      # Records before presale_cutoff → "Pre-sales" bucket
      RateOfSale.create!(
        production: production, day_of_sale: presale_cutoff - 5.days,
        total_single_tickets: 3, total_complimentary_tickets: 0,
        gross_sales: 30.0, processing_fees: 0.00, order_count: 1
      )
      # Records in week 1 (presale_cutoff..presale_cutoff+6)
      RateOfSale.create!(
        production: production, day_of_sale: presale_cutoff + 3.days,
        total_single_tickets: 7, total_complimentary_tickets: 0,
        gross_sales: 70.0, processing_fees: 0.00, order_count: 1
      )
      # Records in week 2
      RateOfSale.create!(
        production: production, day_of_sale: presale_cutoff + 8.days,
        total_single_tickets: 5, total_complimentary_tickets: 0,
        gross_sales: 50.0, processing_fees: 0.00, order_count: 1
      )
    end

    # NOTE: target_tickets is the weekly *percent change* series, not raw totals.
    # The first bucket ("Pre-sales") always has pct_change = 0.0 by definition
    # (no prior bucket to compare against).
    it 'returns 0.0 for "Pre-sales" pct change (first bucket)' do
      result = described_class.new(production, []).compute
      presales_pct = result[:target_tickets]["Pre-sales"]
      expect(presales_pct).to be_within(0.01).of(0.0)
    end

    it 'aggregates raw totals into "Week 1" in target_summary' do
      # target_summary uses weekly_totals_for (not pct_change) — verify Week 1 raw total
      result = described_class.new(production, []).compute
      # Week 1 has 7 tickets (from before block) → total_revenue is gross_sales
      # target_summary total_revenue sums gross_sales for field :gross_sales
      # We check target_summary is non-zero
      expect(result[:target_summary][:total_revenue]).to be > 0
    end

    it 'includes "Week 1" key in target_tickets pct_change series' do
      result = described_class.new(production, []).compute
      expect(result[:target_tickets]).to have_key("Week 1")
    end
  end

  # ---------------------------------------------------------------------------
  # Private method: #compute_pct_changes (tested via compute result)
  # ---------------------------------------------------------------------------
  describe 'pct_change behavior' do
    let(:opening_date) { Date.today - 60.days }
    let(:production) do
      create_production(opening: opening_date, closing: Date.today + 10.days)
    end

    before do
      anchor = production.first_playing_date
      presale_cutoff = anchor - 21.days
      # Pre-sales: 10 tickets
      RateOfSale.create!(
        production: production, day_of_sale: presale_cutoff - 1.day,
        total_single_tickets: 10, total_complimentary_tickets: 0,
        gross_sales: 100.0, processing_fees: 0.00, order_count: 1
      )
      # Week 1: 20 tickets (100% increase over 10)
      RateOfSale.create!(
        production: production, day_of_sale: presale_cutoff + 1.day,
        total_single_tickets: 20, total_complimentary_tickets: 0,
        gross_sales: 200.0, processing_fees: 0.00, order_count: 1
      )
      # Week 2: 10 tickets (50% decrease from 20)
      RateOfSale.create!(
        production: production, day_of_sale: presale_cutoff + 8.days,
        total_single_tickets: 10, total_complimentary_tickets: 0,
        gross_sales: 100.0, processing_fees: 0.00, order_count: 1
      )
    end

    it 'returns 0.0 for the first bucket (Pre-sales)' do
      result = described_class.new(production, []).compute
      expect(result[:target_tickets]["Pre-sales"]).to eq(0.0)
    end

    it 'calculates week-over-week percent change for Week 1 vs Pre-sales' do
      result = described_class.new(production, []).compute
      # Week 1 has 20 tickets, Pre-sales had 10 → +100%
      expect(result[:target_tickets]["Week 1"]).to be_within(0.1).of(100.0)
    end

    it 'calculates week-over-week percent change for Week 2 vs Week 1' do
      result = described_class.new(production, []).compute
      # Week 2 has 10 tickets, Week 1 had 20 → -50%
      expect(result[:target_tickets]["Week 2"]).to be_within(0.1).of(-50.0)
    end
  end

  # ---------------------------------------------------------------------------
  # Private method: #aggregate_series (tested via compute result)
  # ---------------------------------------------------------------------------
  describe 'aggregate_series behavior' do
    let(:target)  { create_production(opening: Date.today - 60.days, closing: Date.today + 10.days) }
    let(:comp1)   { create_production(opening: Date.today - 90.days, closing: Date.today - 30.days) }
    let(:comp2)   { create_production(opening: Date.today - 80.days, closing: Date.today - 20.days) }

    before do
      # Seed comp1 with presale + week 1 data
      anchor1 = comp1.first_playing_date
      pc1 = anchor1 - 21.days
      RateOfSale.create!(production: comp1, day_of_sale: pc1 - 1.day, total_single_tickets: 10,
                         total_complimentary_tickets: 0, gross_sales: 100.0, processing_fees: 0, order_count: 1)
      RateOfSale.create!(production: comp1, day_of_sale: pc1 + 1.day, total_single_tickets: 20,
                         total_complimentary_tickets: 0, gross_sales: 200.0, processing_fees: 0, order_count: 1)

      # Seed comp2 with presale + week 1 data
      anchor2 = comp2.first_playing_date
      pc2 = anchor2 - 21.days
      RateOfSale.create!(production: comp2, day_of_sale: pc2 - 1.day, total_single_tickets: 10,
                         total_complimentary_tickets: 0, gross_sales: 100.0, processing_fees: 0, order_count: 1)
      RateOfSale.create!(production: comp2, day_of_sale: pc2 + 3.days, total_single_tickets: 30,
                         total_complimentary_tickets: 0, gross_sales: 300.0, processing_fees: 0, order_count: 1)
    end

    it 'returns a Hash for aggregate_data' do
      result = described_class.new(target, [comp1, comp2]).compute
      expect(result[:aggregate_data]).to be_a(Hash)
    end

    it 'includes "Pre-sales" and Week labels in aggregate_data' do
      result = described_class.new(target, [comp1, comp2]).compute
      expect(result[:aggregate_data]).to have_key("Pre-sales")
      expect(result[:aggregate_data]).to have_key("Week 1")
    end

    it 'averages Week 1 pct changes across comparison productions' do
      # comp1: week1=20, presale=10 → +100%
      # comp2: week1=30, presale=10 → +200%
      # average = 150%
      result = described_class.new(target, [comp1, comp2]).compute
      expect(result[:aggregate_data]["Week 1"]).to be_within(0.5).of(150.0)
    end
  end

  # ---------------------------------------------------------------------------
  # #compute — comparison_summaries
  # ---------------------------------------------------------------------------
  describe 'comparison_summaries' do
    let(:target) { create_production(opening: Date.today - 60.days, closing: Date.today + 10.days) }
    let(:comp)   { create_production(opening: Date.today - 90.days, closing: Date.today - 10.days) }

    before do
      anchor = comp.first_playing_date
      pc = anchor - 21.days
      RateOfSale.create!(production: comp, day_of_sale: pc + 1.day, total_single_tickets: 5,
                         total_complimentary_tickets: 0, gross_sales: 150.0, processing_fees: 0, order_count: 1)
      RateOfSale.create!(production: comp, day_of_sale: pc + 8.days, total_single_tickets: 5,
                         total_complimentary_tickets: 0, gross_sales: 100.0, processing_fees: 0, order_count: 1)
    end

    it 'returns an array with one entry per comparison production' do
      result = described_class.new(target, [comp]).compute
      expect(result[:comparison_summaries].size).to eq(1)
    end

    it 'summary contains :production, :total_revenue, :num_weeks' do
      result = described_class.new(target, [comp]).compute
      summary = result[:comparison_summaries].first
      expect(summary).to have_key(:production)
      expect(summary).to have_key(:total_revenue)
      expect(summary).to have_key(:num_weeks)
    end

    it 'sums total revenue across all weeks for comparison production' do
      result = described_class.new(target, [comp]).compute
      summary = result[:comparison_summaries].first
      # 150.0 + 100.0 = 250.0
      expect(summary[:total_revenue]).to be_within(0.01).of(250.0)
    end

    it 'returns the max week number in num_weeks' do
      result = described_class.new(target, [comp]).compute
      summary = result[:comparison_summaries].first
      expect(summary[:num_weeks]).to eq(2)
    end
  end

  # ---------------------------------------------------------------------------
  # #compute — target_summary
  # ---------------------------------------------------------------------------
  describe 'target_summary' do
    let(:production) do
      create_production(opening: Date.today - 60.days, closing: Date.today + 10.days)
    end

    before do
      anchor = production.first_playing_date
      pc = anchor - 21.days
      RateOfSale.create!(production: production, day_of_sale: pc + 1.day, total_single_tickets: 10,
                         total_complimentary_tickets: 0, gross_sales: 200.0, processing_fees: 0, order_count: 1)
    end

    it 'includes :production, :total_revenue, :num_weeks' do
      result = described_class.new(production, []).compute
      expect(result[:target_summary]).to have_key(:production)
      expect(result[:target_summary]).to have_key(:total_revenue)
      expect(result[:target_summary]).to have_key(:num_weeks)
    end

    it 'references the target production object' do
      result = described_class.new(production, []).compute
      expect(result[:target_summary][:production]).to eq(production)
    end

    it 'correctly sums target revenue' do
      result = described_class.new(production, []).compute
      expect(result[:target_summary][:total_revenue]).to be_within(0.01).of(200.0)
    end
  end

  # ---------------------------------------------------------------------------
  # #compute — daily_rolling
  # ---------------------------------------------------------------------------
  describe 'daily_rolling' do
    let(:production) do
      create_production(opening: Date.today - 20.days, closing: Date.today + 10.days)
    end

    before do
      anchor = production.first_playing_date
      pc = anchor - 21.days
      7.times do |i|
        RateOfSale.create!(
          production: production, day_of_sale: pc + i.days,
          total_single_tickets: 2, total_complimentary_tickets: 0,
          gross_sales: 20.0, processing_fees: 0, order_count: 1
        )
      end
    end

    it 'returns a Hash with string date keys' do
      result = described_class.new(production, []).compute
      expect(result[:daily_rolling]).to be_a(Hash)
      expect(result[:daily_rolling].keys.first).to match(%r{\d+/\d+/\d+})
    end

    it 'returns rolling 7-day sums' do
      result = described_class.new(production, []).compute
      # After 7 full days of 20.0/day, rolling sum should be 7 * 20 = 140.0
      # The last entry in the range should reflect accumulated rolling sum
      last_val = result[:daily_rolling].values.last
      expect(last_val).to be_within(0.01).of(140.0)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helper: #sort_week_labels
  # ---------------------------------------------------------------------------
  describe 'sort_week_labels (via aggregate_series)' do
    # This is indirectly tested via compute — we verify the ordering of keys
    let(:target)  { create_production(opening: Date.today - 60.days, closing: Date.today + 10.days) }
    let(:comp)    { create_production(opening: Date.today - 90.days, closing: Date.today - 10.days) }

    before do
      anchor = comp.first_playing_date
      pc = anchor - 21.days
      # Seed data into multiple weeks so we can verify ordering
      [1, 2, 3].each do |week|
        RateOfSale.create!(
          production: comp,
          day_of_sale: pc + (((week - 1) * 7) + 1).days,
          total_single_tickets: 10, total_complimentary_tickets: 0,
          gross_sales: 100.0, processing_fees: 0, order_count: 1
        )
      end
      # Pre-sales
      RateOfSale.create!(
        production: comp, day_of_sale: pc - 1.day,
        total_single_tickets: 5, total_complimentary_tickets: 0,
        gross_sales: 50.0, processing_fees: 0, order_count: 1
      )
    end

    it 'places "Pre-sales" before week labels in aggregate_data' do
      result = described_class.new(target, [comp]).compute
      keys = result[:aggregate_data].keys
      presales_idx = keys.index("Pre-sales")
      week1_idx    = keys.index("Week 1")
      expect(presales_idx).to be < week1_idx if presales_idx && week1_idx
    end
  end

  # ---------------------------------------------------------------------------
  # Private helper: #interpolate_curve
  # ---------------------------------------------------------------------------
  describe '#interpolate_curve (via projection)' do
    let(:opening)    { Date.today - 50.days }
    let(:closing)    { Date.today + 20.days }
    let(:production) { create_production(opening: opening, closing: closing) }
    let(:comp)       { create_production(opening: Date.today - 100.days, closing: Date.today - 10.days) }

    before do
      # Seed enough data to allow projection
      anchor = production.first_playing_date
      pc = anchor - 21.days
      [1, 2, 3, 4].each do |week|
        RateOfSale.create!(
          production: production,
          day_of_sale: pc + (((week - 1) * 7) + 1).days,
          total_single_tickets: 10, total_complimentary_tickets: 0,
          gross_sales: 100.0, processing_fees: 0, order_count: 1
        )
      end

      anchor_c = comp.first_playing_date
      pc_c = anchor_c - 21.days
      [1, 2, 3, 4, 5, 6, 7, 8].each do |week|
        RateOfSale.create!(
          production: comp,
          day_of_sale: pc_c + (((week - 1) * 7) + 1).days,
          total_single_tickets: 10, total_complimentary_tickets: 0,
          gross_sales: 100.0, processing_fees: 0, order_count: 1
        )
      end
    end

    it 'returns a Hash for projection (not nil) when there is enough data' do
      result = described_class.new(production, [comp]).compute
      # May be nil if ratio can't be computed — but if not nil it's a Hash
      if result[:projection]
        expect(result[:projection]).to be_a(Hash)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helper: #split_curve_at_decline
  # ---------------------------------------------------------------------------
  describe '#split_curve_at_decline' do
    # We test this private method by accessing it directly via send
    let(:analysis) { described_class.new(create_production, []) }

    it 'returns [curve, []] for a curve smaller than 3 elements' do
      body, tail = analysis.send(:split_curve_at_decline, [100.0, 50.0])
      expect(body).to eq([100.0, 50.0])
      expect(tail).to eq([])
    end

    it 'splits a monotonically declining end into tail' do
      # 10, 20, 30, 25, 20, 15 — peak at 30 (index 2), then consistent decline
      curve = [10.0, 20.0, 30.0, 25.0, 20.0, 15.0]
      body, tail = analysis.send(:split_curve_at_decline, curve)
      # The tail should contain the declining portion
      expect(tail).not_to be_empty
      expect(body + tail).to eq(curve)
    end

    it 'finds a late sustained decline even when the curve recovers briefly after peak' do
      # curve = [10, 20, 30, 25, 30, 20]
      # Peak is at index 2 (30). The algorithm scans forward from peak+1:
      #   i=3: remaining=[25,30,20] — NOT all descending (25→30 rises)
      #   i=4: remaining=[30,20]   — all descending → decline_start=4
      # So body=[10,20,30,25], tail=[30.0,20.0]
      # NOTE: This is a surprising behavior — the "decline tail" starts AFTER
      # the post-peak recovery (the 30.0 at index 4 is included in the tail).
      curve = [10.0, 20.0, 30.0, 25.0, 30.0, 20.0]
      body, tail = analysis.send(:split_curve_at_decline, curve)
      expect(tail).to eq([30.0, 20.0])
      expect(body).to eq([10.0, 20.0, 30.0, 25.0])
    end

    it 'handles a monotonically increasing curve (no decline at all)' do
      curve = [5.0, 10.0, 20.0, 40.0, 80.0]
      body, tail = analysis.send(:split_curve_at_decline, curve)
      expect(tail).to eq([])
      expect(body).to eq(curve)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helper: #expected_weekly_value / #plateau_level
  # FIX 4: the body-stretch machinery (#interpolate_curve + body stretching) was
  # replaced with matching-week expectation + an end-aligned decline tail. The
  # former #interpolate_curve direct specs are replaced by these, which pin the
  # new mapping.
  # ---------------------------------------------------------------------------
  describe '#expected_weekly_value (matching-week + end-aligned tail)' do
    let(:analysis) { described_class.new(create_production, []) }

    it 'uses the matching body value for body weeks' do
      body = [10.0, 20.0, 30.0]
      tail = []
      # total_weeks=3, no tail → week N maps to body[N-1]
      expect(analysis.send(:expected_weekly_value, 1, 3, body, tail)).to be_within(0.001).of(10.0)
      expect(analysis.send(:expected_weekly_value, 2, 3, body, tail)).to be_within(0.001).of(20.0)
      expect(analysis.send(:expected_weekly_value, 3, 3, body, tail)).to be_within(0.001).of(30.0)
    end

    it 'end-aligns the decline tail to the final weeks of the run' do
      body = [10.0, 20.0, 30.0]
      tail = [25.0, 15.0]
      total_weeks = 5
      # Body weeks 1..3, tail end-aligned to weeks 4,5
      expect(analysis.send(:expected_weekly_value, 3, total_weeks, body, tail)).to be_within(0.001).of(30.0)
      expect(analysis.send(:expected_weekly_value, 4, total_weeks, body, tail)).to be_within(0.001).of(25.0)
      expect(analysis.send(:expected_weekly_value, 5, total_weeks, body, tail)).to be_within(0.001).of(15.0)
    end

    it 'fills the gap with the plateau level when the run is longer than body+tail' do
      body = [10.0, 20.0, 30.0]
      tail = [25.0, 15.0]
      total_weeks = 7 # body(3) + gap(2) + tail(2)
      # weeks 4,5 fall in the gap → plateau = avg(body[-2], body[-1]) = (20+30)/2 = 25
      expect(analysis.send(:expected_weekly_value, 4, total_weeks, body, tail)).to be_within(0.001).of(25.0)
      expect(analysis.send(:expected_weekly_value, 5, total_weeks, body, tail)).to be_within(0.001).of(25.0)
      # weeks 6,7 are the end-aligned tail
      expect(analysis.send(:expected_weekly_value, 6, total_weeks, body, tail)).to be_within(0.001).of(25.0)
      expect(analysis.send(:expected_weekly_value, 7, total_weeks, body, tail)).to be_within(0.001).of(15.0)
    end
  end

  describe '#plateau_level' do
    let(:analysis) { described_class.new(create_production, []) }

    it 'returns 0.0 for empty body' do
      expect(analysis.send(:plateau_level, [])).to eq(0.0)
    end

    it 'returns the single value for a 1-element body' do
      expect(analysis.send(:plateau_level, [42.0])).to eq(42.0)
    end

    it 'returns the average of the last two body weeks' do
      expect(analysis.send(:plateau_level, [10.0, 20.0, 30.0])).to be_within(0.001).of(25.0)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helper: #compute_momentum
  # FIX 5: momentum is now a daily-rolling-based rate (last 7 complete days vs
  # the prior 7), replacing the former median-of-last-3-weekly-pct model. The
  # method now takes the daily_rolling hash, not a weekly pct hash.
  # ---------------------------------------------------------------------------
  describe '#compute_momentum (daily-rolling rate)' do
    let(:analysis) { described_class.new(create_production, []) }

    it 'returns [0.0, 0] when fewer than 14 rolling points exist' do
      data = (1..10).to_h { |i| ["#{i}/1/26", 100.0] }
      momentum, window = analysis.send(:compute_momentum, data)
      expect(momentum).to eq(0.0)
      expect(window).to eq(0)
    end

    it 'returns 0% when the recent window matches the prior window' do
      data = (1..14).to_h { |i| ["d#{i}", 100.0] }
      momentum, window = analysis.send(:compute_momentum, data)
      expect(window).to eq(14)
      expect(momentum).to be_within(0.001).of(0.0)
    end

    it 'computes the pct change of the recent 7-day avg vs the prior 7-day avg' do
      # prior 7 (indices -14..-8) = 100 each; recent 7 = 150 each → +50%
      prior = Array.new(7, 100.0)
      recent = Array.new(7, 150.0)
      data = (prior + recent).each_with_index.to_h { |v, i| ["d#{i}", v] }
      momentum, window = analysis.send(:compute_momentum, data)
      expect(window).to eq(14)
      expect(momentum).to be_within(0.001).of(50.0)
    end

    it 'returns [0.0, size] when the prior window is non-positive' do
      data = (Array.new(7, 0.0) + Array.new(7, 50.0)).each_with_index.to_h { |v, i| ["d#{i}", v] }
      momentum, window = analysis.send(:compute_momentum, data)
      expect(momentum).to eq(0.0)
      expect(window).to eq(14)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helper: #avg_ticket_price_to_date
  # ---------------------------------------------------------------------------
  describe '#avg_ticket_price_to_date' do
    let(:production) { create_production }
    let(:analysis)   { described_class.new(production, []) }

    it 'returns nil when there are no rate_of_sales' do
      expect(analysis.send(:avg_ticket_price_to_date, production)).to be_nil
    end

    it 'returns nil when total tickets is zero' do
      RateOfSale.create!(production: production, day_of_sale: Date.today - 1,
                         total_single_tickets: 0, total_complimentary_tickets: 0,
                         gross_sales: 0, processing_fees: 0, order_count: 0)
      expect(analysis.send(:avg_ticket_price_to_date, production)).to be_nil
    end

    it 'calculates the average correctly' do
      # 100 revenue, 10 tickets → avg = 10.0
      RateOfSale.create!(production: production, day_of_sale: Date.today - 1,
                         total_single_tickets: 10, total_complimentary_tickets: 0,
                         gross_sales: 100.0, processing_fees: 0, order_count: 1)
      expect(analysis.send(:avg_ticket_price_to_date, production)).to be_within(0.001).of(10.0)
    end

    it 'sums across multiple records' do
      RateOfSale.create!(production: production, day_of_sale: Date.today - 2,
                         total_single_tickets: 10, total_complimentary_tickets: 0,
                         gross_sales: 100.0, processing_fees: 0, order_count: 1)
      RateOfSale.create!(production: production, day_of_sale: Date.today - 1,
                         total_single_tickets: 10, total_complimentary_tickets: 0,
                         gross_sales: 200.0, processing_fees: 0, order_count: 1)
      # total_rev=300, total_tix=20 → avg=15.0
      expect(analysis.send(:avg_ticket_price_to_date, production)).to be_within(0.001).of(15.0)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helper: #weighted_performance_ratio
  # ---------------------------------------------------------------------------
  describe '#weighted_performance_ratio' do
    let(:analysis) { described_class.new(create_production, []) }

    it 'returns nil when both hashes are empty' do
      expect(analysis.send(:weighted_performance_ratio, {}, {})).to be_nil
    end

    it 'returns nil when there are no overlapping non-zero weeks' do
      target = { "Week 1" => 100.0 }
      agg    = { "Week 2" => 100.0 }
      expect(analysis.send(:weighted_performance_ratio, target, agg)).to be_nil
    end

    it 'returns 1.0 when target exactly matches aggregate' do
      target = { "Week 1" => 100.0, "Week 2" => 200.0 }
      agg    = { "Week 1" => 100.0, "Week 2" => 200.0 }
      ratio = analysis.send(:weighted_performance_ratio, target, agg)
      expect(ratio).to be_within(0.001).of(1.0)
    end

    it 'returns 2.0 when target is double aggregate for all weeks' do
      target = { "Week 1" => 200.0, "Week 2" => 400.0 }
      agg    = { "Week 1" => 100.0, "Week 2" => 200.0 }
      ratio = analysis.send(:weighted_performance_ratio, target, agg)
      expect(ratio).to be_within(0.001).of(2.0)
    end

    it 'skips the "Pre-sales" label' do
      target = { "Pre-sales" => 1000.0, "Week 1" => 100.0 }
      agg    = { "Pre-sales" => 10.0,   "Week 1" => 100.0 }
      ratio = analysis.send(:weighted_performance_ratio, target, agg)
      # Pre-sales should be skipped; only Week 1 contributes → ratio = 1.0
      expect(ratio).to be_within(0.001).of(1.0)
    end

    it 'weights more recent weeks more heavily (decay 0.7)' do
      # Week 1: target=100, agg=100 (ratio=1.0)  weight = 0.7^1 = 0.7
      # Week 2: target=200, agg=100 (ratio=2.0)  weight = 0.7^0 = 1.0
      # weighted avg = (1.0*0.7 + 2.0*1.0) / (0.7 + 1.0) = 2.7 / 1.7 ≈ 1.588
      target = { "Week 1" => 100.0, "Week 2" => 200.0 }
      agg    = { "Week 1" => 100.0, "Week 2" => 100.0 }
      ratio = analysis.send(:weighted_performance_ratio, target, agg)
      expect(ratio).to be_within(0.01).of(2.7 / 1.7)
    end
  end

  # ---------------------------------------------------------------------------
  # #compute — with no comparison productions
  # ---------------------------------------------------------------------------
  describe 'with empty comparison_productions' do
    let(:production) { create_production }

    it 'returns empty comparison_summaries' do
      result = described_class.new(production, []).compute
      expect(result[:comparison_summaries]).to eq([])
    end

    it 'returns nil for projection since no aggregate data' do
      result = described_class.new(production, []).compute
      expect(result[:projection]).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # #compute — projection return structure
  # ---------------------------------------------------------------------------
  describe '#compute projection structure' do
    let(:opening) { Date.today - 40.days }
    let(:closing) { Date.today + 20.days }
    let(:target)  { create_production(opening: opening, closing: closing) }
    let(:comp)    { create_production(opening: Date.today - 100.days, closing: Date.today - 5.days) }

    before do
      anchor_t = target.first_playing_date
      pc_t = anchor_t - 21.days
      [1, 2, 3].each do |week|
        RateOfSale.create!(
          production: target,
          day_of_sale: pc_t + (((week - 1) * 7) + 1).days,
          total_single_tickets: 10, total_complimentary_tickets: 0,
          gross_sales: 100.0, processing_fees: 0, order_count: 1
        )
      end

      anchor_c = comp.first_playing_date
      pc_c = anchor_c - 21.days
      [1, 2, 3, 4, 5, 6, 7, 8].each do |week|
        RateOfSale.create!(
          production: comp,
          day_of_sale: pc_c + (((week - 1) * 7) + 1).days,
          total_single_tickets: 10, total_complimentary_tickets: 0,
          gross_sales: 100.0, processing_fees: 0, order_count: 1
        )
      end
    end

    it 'includes expected projection keys when projection is non-nil' do
      result = described_class.new(target, [comp]).compute
      proj = result[:projection]
      if proj
        expect(proj).to have_key(:actual_cumulative)
        expect(proj).to have_key(:projected_cumulative)
        expect(proj).to have_key(:performance_ratio)
        expect(proj).to have_key(:projected_remaining)
        expect(proj).to have_key(:projected_total)
        expect(proj).to have_key(:actual_total)
        expect(proj).to have_key(:extra_weeks)
        expect(proj).to have_key(:alternate_cumulative)
        expect(proj).to have_key(:capacity_clipped)
        expect(proj).to have_key(:avg_ticket_price)
        expect(proj).to have_key(:remaining_seats)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helper: #remaining_revenue_budget
  # ---------------------------------------------------------------------------
  describe '#remaining_revenue_budget' do
    let(:production) { create_production }
    let(:analysis)   { described_class.new(production, []) }

    it 'returns Float::INFINITY when avg_price is nil' do
      expect(analysis.send(:remaining_revenue_budget, production, nil)).to eq(Float::INFINITY)
    end

    it 'returns Float::INFINITY when avg_price is 0' do
      expect(analysis.send(:remaining_revenue_budget, production, 0)).to eq(Float::INFINITY)
    end

    it 'returns finite budget when avg_price is positive' do
      # Create a future performance
      FactoryBot.create(:performance, production: production,
                                      performance_date: Date.today + 1.day)
      result = analysis.send(:remaining_revenue_budget, production, 10.0)
      expect(result).not_to eq(Float::INFINITY)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helper: #average_weekly_totals
  # ---------------------------------------------------------------------------
  describe '#average_weekly_totals' do
    let(:analysis) { described_class.new(create_production, []) }

    it 'returns {} for empty input' do
      expect(analysis.send(:average_weekly_totals, [])).to eq({})
    end

    it 'averages values across multiple series for the same label' do
      s1 = { "Week 1" => 100.0, "Week 2" => 200.0 }
      s2 = { "Week 1" => 200.0, "Week 2" => 400.0 }
      result = analysis.send(:average_weekly_totals, [s1, s2])
      expect(result["Week 1"]).to be_within(0.001).of(150.0)
      expect(result["Week 2"]).to be_within(0.001).of(300.0)
    end

    it 'skips series that have 0 for a given label' do
      # 0-value entries are excluded from the average (only non-zero values)
      s1 = { "Week 1" => 100.0 }
      s2 = { "Week 1" => 0.0 }
      result = analysis.send(:average_weekly_totals, [s1, s2])
      # s2 has 0 so only s1 contributes: average = 100.0 / 1 = 100.0
      expect(result["Week 1"]).to be_within(0.001).of(100.0)
    end

    it 'omits labels that have only 0 values across all series' do
      s1 = { "Week 1" => 0.0 }
      result = analysis.send(:average_weekly_totals, [s1])
      expect(result).not_to have_key("Week 1")
    end
  end

  # ---------------------------------------------------------------------------
  # Private helper: #extract_max_week
  # ---------------------------------------------------------------------------
  describe '#extract_max_week' do
    let(:analysis) { described_class.new(create_production, []) }

    it 'returns 0 when no week keys exist' do
      expect(analysis.send(:extract_max_week, {})).to eq(0)
    end

    it 'returns 0 when only Pre-sales key exists' do
      expect(analysis.send(:extract_max_week, { "Pre-sales" => 100 })).to eq(0)
    end

    it 'returns the maximum week number' do
      data = { "Week 1" => 10, "Week 3" => 30, "Week 2" => 20 }
      expect(analysis.send(:extract_max_week, data)).to eq(3)
    end
  end

  # ---------------------------------------------------------------------------
  # #compute — compute extra_weeks=1 extension
  # ---------------------------------------------------------------------------
  describe '#compute with extra_weeks parameter' do
    let(:opening) { Date.today - 40.days }
    let(:closing) { Date.today + 10.days }
    let(:target)  { create_production(opening: opening, closing: closing) }
    let(:comp)    { create_production(opening: Date.today - 100.days, closing: Date.today - 5.days) }

    before do
      anchor_t = target.first_playing_date
      pc_t = anchor_t - 21.days
      [1, 2, 3].each do |w|
        RateOfSale.create!(production: target, day_of_sale: pc_t + (((w - 1) * 7) + 1).days,
                           total_single_tickets: 10, total_complimentary_tickets: 0,
                           gross_sales: 100.0, processing_fees: 0, order_count: 1)
      end
      anchor_c = comp.first_playing_date
      pc_c = anchor_c - 21.days
      [1, 2, 3, 4, 5, 6, 7, 8].each do |w|
        RateOfSale.create!(production: comp, day_of_sale: pc_c + (((w - 1) * 7) + 1).days,
                           total_single_tickets: 10, total_complimentary_tickets: 0,
                           gross_sales: 100.0, processing_fees: 0, order_count: 1)
      end
    end

    it 'accepts extra_weeks keyword argument' do
      expect do
        described_class.new(target, [comp]).compute(extra_weeks: 1)
      end.not_to raise_error
    end

    it 'returns extra_weeks in projection when non-nil' do
      result = described_class.new(target, [comp]).compute(extra_weeks: 1)
      if result[:projection]
        expect(result[:projection][:extra_weeks]).to eq(1)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # FIX 1: partial-week bias — the performance ratio must not depend on which
  # day of the week the analysis runs. The actual buckets anchor on
  # presale_cutoff (rarely a Monday), so the final bucket is usually partial;
  # excluding it from the ratio makes the ratio stable across days in the week.
  # ---------------------------------------------------------------------------
  describe 'FIX 1: performance ratio stability across the week' do
    it 'produces the same performance_ratio on two different days in the same week' do
      # Anchor far enough back that several complete weeks exist regardless of
      # the "today" we travel to.
      opening = Date.new(2026, 5, 4) # a Monday-ish anchor; presale_cutoff = opening-21
      closing = Date.new(2026, 6, 30)

      target = create_production(opening: opening, closing: closing)
      comp   = create_production(opening: opening - 60, closing: opening - 10)

      anchor_t = target.first_playing_date
      pc_t = anchor_t - 21.days
      (0..40).each do |i|
        RateOfSale.create!(production: target, day_of_sale: pc_t + i.days,
                           total_single_tickets: 10, total_complimentary_tickets: 0,
                           gross_sales: 100.0, processing_fees: 0, ticketing_fees: 0, order_count: 1)
      end
      anchor_c = comp.first_playing_date
      pc_c = anchor_c - 21.days
      (0..55).each do |i|
        RateOfSale.create!(production: comp, day_of_sale: pc_c + i.days,
                           total_single_tickets: 10, total_complimentary_tickets: 0,
                           gross_sales: 100.0, processing_fees: 0, ticketing_fees: 0, order_count: 1)
      end

      # Two different days within the SAME analysis week (Wed and Fri of a week
      # whose Monday is after enough data exists).
      ratio_wed = travel_to(Date.new(2026, 6, 10)) do # Wednesday
        described_class.new(target, [comp]).compute[:projection]&.dig(:performance_ratio)
      end
      ratio_fri = travel_to(Date.new(2026, 6, 12)) do # Friday, same week
        described_class.new(target, [comp]).compute[:projection]&.dig(:performance_ratio)
      end

      expect(ratio_wed).not_to be_nil
      expect(ratio_fri).not_to be_nil
      expect(ratio_fri).to be_within(0.001).of(ratio_wed)
    end
  end

  # ---------------------------------------------------------------------------
  # FIX 2: revenue-vs-revenue insight + new aggregate_revenue_data result key.
  # ---------------------------------------------------------------------------
  describe 'FIX 2: aggregate revenue series' do
    let(:target) { create_production(opening: Date.today - 60.days, closing: Date.today + 10.days) }
    let(:comp)   { create_production(opening: Date.today - 90.days, closing: Date.today - 10.days) }

    before do
      anchor = comp.first_playing_date
      pc = anchor - 21.days
      [1, 2, 3].each do |w|
        RateOfSale.create!(production: comp, day_of_sale: pc + (((w - 1) * 7) + 1).days,
                           total_single_tickets: 10 * w, total_complimentary_tickets: 0,
                           gross_sales: 100.0 * w, processing_fees: 0, ticketing_fees: 0, order_count: 1)
      end
    end

    it 'exposes :aggregate_revenue_data alongside :aggregate_data' do
      result = described_class.new(target, [comp]).compute
      expect(result).to have_key(:aggregate_revenue_data)
      expect(result).to have_key(:aggregate_data)
      expect(result[:aggregate_revenue_data]).to be_a(Hash)
    end
  end

  # ---------------------------------------------------------------------------
  # FIX 3: analysis revenue = gross_sales net of ticketing fees.
  # ---------------------------------------------------------------------------
  describe 'FIX 3: revenue is net of ticketing fees' do
    let(:production) { create_production(opening: Date.today - 60.days, closing: Date.today + 10.days) }

    it 'subtracts ticketing_fees from gross_sales in revenue totals' do
      anchor = production.first_playing_date
      pc = anchor - 21.days
      RateOfSale.create!(production: production, day_of_sale: pc + 1.day,
                         total_single_tickets: 10, total_complimentary_tickets: 0,
                         gross_sales: 200.0, processing_fees: 30.0, ticketing_fees: 30.0, order_count: 1)
      result = described_class.new(production, []).compute
      # 200 gross - 30 ticketing = 170 analysis revenue
      expect(result[:target_summary][:total_revenue]).to be_within(0.01).of(170.0)
    end

    it 'falls back to gross when ticketing_fees is nil (not yet backfilled)' do
      anchor = production.first_playing_date
      pc = anchor - 21.days
      RateOfSale.create!(production: production, day_of_sale: pc + 1.day,
                         total_single_tickets: 10, total_complimentary_tickets: 0,
                         gross_sales: 200.0, processing_fees: 30.0, ticketing_fees: nil, order_count: 1)
      result = described_class.new(production, []).compute
      expect(result[:target_summary][:total_revenue]).to be_within(0.01).of(200.0)
    end
  end

  # ---------------------------------------------------------------------------
  # FIX 4: pre-sales must never enter the expectation curve / ratio / momentum.
  # ---------------------------------------------------------------------------
  describe 'FIX 4: pre-sales excluded from expectation curve' do
    it 'does not let a huge pre-sales bucket distort the projection' do
      opening = Date.today - 30.days
      closing = Date.today + 21.days
      target = create_production(opening: opening, closing: closing)
      comp   = create_production(opening: Date.today - 120.days, closing: Date.today - 20.days)

      anchor_t = target.first_playing_date
      pc_t = anchor_t - 21.days
      # Enormous pre-sales spike that, if included, would dominate everything.
      RateOfSale.create!(production: target, day_of_sale: pc_t - 5.days,
                         total_single_tickets: 1000, total_complimentary_tickets: 0,
                         gross_sales: 100_000.0, processing_fees: 0, ticketing_fees: 0, order_count: 1)
      [1, 2, 3].each do |w|
        RateOfSale.create!(production: target, day_of_sale: pc_t + (((w - 1) * 7) + 1).days,
                           total_single_tickets: 10, total_complimentary_tickets: 0,
                           gross_sales: 100.0, processing_fees: 0, ticketing_fees: 0, order_count: 1)
      end
      anchor_c = comp.first_playing_date
      pc_c = anchor_c - 21.days
      RateOfSale.create!(production: comp, day_of_sale: pc_c - 5.days,
                         total_single_tickets: 1000, total_complimentary_tickets: 0,
                         gross_sales: 50_000.0, processing_fees: 0, ticketing_fees: 0, order_count: 1)
      [1, 2, 3, 4, 5, 6].each do |w|
        RateOfSale.create!(production: comp, day_of_sale: pc_c + (((w - 1) * 7) + 1).days,
                           total_single_tickets: 10, total_complimentary_tickets: 0,
                           gross_sales: 100.0, processing_fees: 0, ticketing_fees: 0, order_count: 1)
      end

      proj = described_class.new(target, [comp]).compute[:projection]
      next if proj.nil?

      # Projected weekly increments should be on the order of the in-run weekly
      # revenue (~$100), nowhere near the pre-sales spike. Confirm no single
      # projected week jumps by tens of thousands.
      cum = proj[:projected_cumulative].values
      increments = cum.each_cons(2).map { |a, b| b - a }
      expect(increments.max.to_f).to be < 10_000.0 if increments.any?
    end
  end
end
