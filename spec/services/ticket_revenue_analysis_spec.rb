# frozen_string_literal: true

require 'rails_helper'

# Characterization specs for TicketRevenueAnalysis.
# These pin down *existing* behavior — they do NOT change app code.
RSpec.describe TicketRevenueAnalysis, type: :service do
  # ---------------------------------------------------------------------------
  # Helpers that avoid the FactoryBot production/ticket_class factory's
  # find_or_create_by(class_code:) bug which causes test-to-test contamination.
  # ---------------------------------------------------------------------------
  let(:theater) { FactoryBot.create(:theater) }
  let(:venue)   { FactoryBot.create(:venue) }

  def make_production(capacity: 100, closing: Date.today + 30.days)
    @prod_seq ||= 0
    @prod_seq += 1
    prod = Production.new(
      name:             "Test Prod #{@prod_seq}",
      production_code:  "TP#{@prod_seq.to_s.rjust(4, '0')}",
      capacity:         capacity,
      closing_at:       closing,
      opening_at:       Date.today - 14.days,
      first_preview_at: Date.today - 14.days,
      press_opening_at: Date.today - 14.days,
      season:           Date.today.year,
      status:           Production::ACTIVE,
      theater:          theater,
      venue:            venue
    )
    prod.save!
    prod
  end

  def make_ticket_class(production, price: 25.0, code: nil, comp: false, royalty: nil, fee: 0.0)
    @tc_seq ||= 0
    @tc_seq += 1
    code ||= "T#{@tc_seq.to_s.rjust(3, '0')}"
    TicketClass.create!(
      production:       production,
      class_code:       code,
      class_name:       "Class #{code}",
      ticket_type:      'Fixed',
      ticket_price:     price,
      ticketing_fee:    fee,
      complimentary:    comp,
      royalty_amount:   royalty,
      web_visible:      true,
      auto_attach:      false,
      software_managed: false,
      holds_seats:      true
    )
  end

  def make_performance(production)
    @perf_seq ||= 0
    @perf_seq += 1
    perf_code = "#{production.production_code}#{@perf_seq.to_s.rjust(2, '0')}"[0, 8]
    perf_date = Date.today + 10.days + @perf_seq.days
    perf_time = Time.now.beginning_of_day + (18 + @perf_seq).hours
    Performance.create!(
      performance_code:  perf_code,
      production:        production,
      performance_date:  perf_date,
      performance_time:  perf_time,
      status:            Performance::PERFORMANCE_STATUSES.first
    )
  end

  def make_order_with_line_item(performance, ticket_class, count: 1)
    order = TicketOrder.create!(
      status:       Order::NEW,
      performance:  performance,
      address:      FactoryBot.create(:address),
      payment_type: FactoryBot.create(:cash_payment_type)
    )
    TicketLineItem.create!(order: order, ticket_class: ticket_class, ticket_count: count)
    order.update_column(:status, Order::PROCESSED)
    order.reload
    order
  end

  def make_allocation(performance, ticket_class, limit: nil, shiftable: false, shift_to_code: nil)
    attrs = { performance: performance, ticket_class: ticket_class, available: true }
    attrs[:ticket_limit] = limit if limit
    attrs[:shiftable] = shiftable
    attrs[:shift_to_code] = shift_to_code if shift_to_code
    attrs[:shift_days_before_performance] = 999 if shiftable && shift_to_code
    TicketClassAllocation.create!(attrs)
  end

  # ---------------------------------------------------------------------------
  # Structs
  # ---------------------------------------------------------------------------
  describe 'BucketResult struct' do
    it 'is a Struct with the expected keys' do
      fields = %i[name ticket_class_ids class_codes entry_price bucket_type
                  paid_count avg_paid_price price_min price_max ladder_distribution
                  class_breakdown actual_gross flat_base_gross dynamic_lift_dollars
                  dynamic_lift_pct bucket_allocation allocation_from_limit
                  sell_through_pct allocation_cap_hit]
      fields.each { |f| expect(TicketRevenueAnalysis::BucketResult.members).to include(f) }
    end
  end

  describe 'Summary struct' do
    it 'is a Struct with the expected keys' do
      fields = %i[production buckets comp_count total_capacity total_paid
                  capacity_utilization_pct gross_revenue cash_collected
                  overall_avg_paid_price total_dynamic_lift_dollars total_dynamic_lift_pct
                  performance_count completed_performance_count special_offer_usage]
      fields.each { |f| expect(TicketRevenueAnalysis::Summary.members).to include(f) }
    end
  end

  describe 'OfferUsage struct' do
    it 'is a Struct with the expected keys' do
      expect(TicketRevenueAnalysis::OfferUsage.members).to include(:code, :description, :uses, :total_discount, :class_swap)
    end
  end

  # ---------------------------------------------------------------------------
  # #compute — empty production (no ticket classes)
  # ---------------------------------------------------------------------------
  describe '#compute with a production that has no ticket classes' do
    let(:production) { make_production(capacity: 50) }
    subject(:result) { described_class.new(production).compute }

    it 'returns a Summary struct' do
      expect(result).to be_a(TicketRevenueAnalysis::Summary)
    end

    it 'returns empty buckets array' do
      expect(result.buckets).to eq([])
    end

    it 'returns 0 for comp_count' do
      expect(result.comp_count).to eq(0)
    end

    it 'returns 0 for total_capacity' do
      expect(result.total_capacity).to eq(0)
    end

    it 'returns 0 for total_paid' do
      expect(result.total_paid).to eq(0)
    end

    it 'returns 0 for capacity_utilization_pct' do
      expect(result.capacity_utilization_pct).to eq(0)
    end

    it 'returns BigDecimal(0) for gross_revenue' do
      expect(result.gross_revenue).to eq(BigDecimal('0'))
    end

    it 'returns BigDecimal(0) for overall_avg_paid_price' do
      expect(result.overall_avg_paid_price).to eq(BigDecimal('0'))
    end

    it 'returns nil for total_dynamic_lift_pct' do
      expect(result.total_dynamic_lift_pct).to be_nil
    end

    it 'returns empty array for special_offer_usage' do
      expect(result.special_offer_usage).to eq([])
    end

    it 'returns 0 for performance_count when no performances exist' do
      expect(result.performance_count).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # #compute — ticket classes but no sales
  # ---------------------------------------------------------------------------
  describe '#compute with ticket classes but no sales' do
    let(:production)  { make_production(capacity: 100) }
    let!(:tc)         { make_ticket_class(production, price: 30.0, code: 'FULL') }
    let!(:perf)       { make_performance(production) }
    before            { make_allocation(perf, tc) }
    subject(:result)  { described_class.new(production).compute }

    it 'returns empty buckets when no orders exist' do
      expect(result.buckets).to be_empty
    end

    it 'total_paid is 0' do
      expect(result.total_paid).to eq(0)
    end

    it 'gross_revenue is 0' do
      expect(result.gross_revenue).to eq(BigDecimal('0'))
    end

    it 'performance_count is 1' do
      expect(result.performance_count).to eq(1)
    end
  end

  # ---------------------------------------------------------------------------
  # #compute — singleton ticket class with sales
  # ---------------------------------------------------------------------------
  describe '#compute with a single paid ticket class and sales' do
    let(:production)   { make_production(capacity: 200) }
    let!(:tc)          { make_ticket_class(production, price: 25.0, code: 'FULL') }
    let!(:perf)        { make_performance(production) }

    before do
      make_allocation(perf, tc, limit: 50)
      make_order_with_line_item(perf, tc, count: 2)
      make_order_with_line_item(perf, tc, count: 3)
    end

    subject(:result) { described_class.new(production).compute }

    it 'returns a Summary' do
      expect(result).to be_a(TicketRevenueAnalysis::Summary)
    end

    it 'returns one bucket' do
      expect(result.buckets.size).to eq(1)
    end

    it 'bucket type is :singleton' do
      expect(result.buckets.first.bucket_type).to eq(:singleton)
    end

    it 'counts all sold tickets as paid_count (2 + 3 = 5)' do
      expect(result.buckets.first.paid_count).to eq(5)
    end

    it 'calculates avg_paid_price as entry_price when no overrides' do
      expect(result.buckets.first.avg_paid_price).to eq(BigDecimal('25.0'))
    end

    it 'calculates actual_gross correctly (5 * 25 = 125)' do
      expect(result.buckets.first.actual_gross).to eq(BigDecimal('125.0'))
    end

    it 'sets flat_base_gross = entry_price * paid_count' do
      expect(result.buckets.first.flat_base_gross).to eq(BigDecimal('125.0'))
    end

    it 'dynamic_lift_dollars is zero for singleton (no premium over entry price)' do
      expect(result.buckets.first.dynamic_lift_dollars).to eq(BigDecimal('0'))
    end

    it 'calculates total_paid from paid buckets' do
      expect(result.total_paid).to eq(5)
    end

    it 'calculates gross_revenue correctly' do
      expect(result.gross_revenue).to eq(BigDecimal('125.0'))
    end

    it 'calculates overall_avg_paid_price' do
      expect(result.overall_avg_paid_price).to eq(BigDecimal('25.0'))
    end

    it 'calculates total_capacity as production.capacity * perf_count' do
      expect(result.total_capacity).to eq(200)
    end

    it 'calculates capacity_utilization_pct' do
      expect(result.capacity_utilization_pct).to eq(2.5)
    end

    it 'uses the ticket_limit for sell_through calculation (5 / 50 = 10.0%)' do
      expect(result.buckets.first.sell_through_pct).to eq(10.0)
    end

    it 'sets allocation_from_limit to true when limit exists' do
      expect(result.buckets.first.allocation_from_limit).to be true
    end

    it 'sets allocation_cap_hit to false when under limit' do
      expect(result.buckets.first.allocation_cap_hit).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # #compute — multiple performances
  # ---------------------------------------------------------------------------
  describe '#compute total_capacity with multiple performances' do
    let(:production) { make_production(capacity: 100) }
    let!(:tc)        { make_ticket_class(production, price: 20.0, code: 'GA') }
    let!(:perf1)     { make_performance(production) }
    let!(:perf2)     { make_performance(production) }

    before do
      make_allocation(perf1, tc)
      make_allocation(perf2, tc)
    end

    it 'multiplies capacity by performance count' do
      result = described_class.new(production).compute
      expect(result.performance_count).to eq(2)
      expect(result.total_capacity).to eq(200)
    end
  end

  # ---------------------------------------------------------------------------
  # #compute — sorting paid buckets by avg price desc
  # ---------------------------------------------------------------------------
  describe '#compute with multiple singleton ticket classes (sorting)' do
    let(:production) { make_production(capacity: 300) }
    let!(:cheap_tc)  { make_ticket_class(production, price: 10.0, code: 'CHP') }
    let!(:prem_tc)   { make_ticket_class(production, price: 50.0, code: 'PRM') }
    let!(:perf)      { make_performance(production) }

    before do
      make_allocation(perf, cheap_tc)
      make_allocation(perf, prem_tc)
      make_order_with_line_item(perf, cheap_tc, count: 5)
      make_order_with_line_item(perf, prem_tc, count: 3)
    end

    subject(:result) { described_class.new(production).compute }

    it 'returns two buckets' do
      expect(result.buckets.size).to eq(2)
    end

    it 'sorts paid buckets with highest avg price first' do
      expect(result.buckets.first.avg_paid_price).to be >= result.buckets.last.avg_paid_price
    end

    it 'the premium class bucket is first' do
      expect(result.buckets.first.class_codes).to include('PRM')
    end

    it 'sums gross_revenue across all buckets (5*10 + 3*50 = 200)' do
      expect(result.gross_revenue).to eq(BigDecimal('200.0'))
    end

    it 'sums total_paid across all buckets (5 + 3 = 8)' do
      expect(result.total_paid).to eq(8)
    end
  end

  # ---------------------------------------------------------------------------
  # #compute — complimentary ticket class
  # ---------------------------------------------------------------------------
  describe '#compute with complimentary ticket class' do
    let(:production) { make_production(capacity: 100) }
    let!(:comp_tc)   { make_ticket_class(production, price: 0.0, code: 'CMP', comp: true) }
    let!(:perf)      { make_performance(production) }

    before do
      make_allocation(perf, comp_tc)
      make_order_with_line_item(perf, comp_tc, count: 3)
    end

    subject(:result) { described_class.new(production).compute }

    it 'creates a comp bucket of type :comp' do
      comp_bucket = result.buckets.find { |b| b.bucket_type == :comp }
      expect(comp_bucket).not_to be_nil
    end

    it 'comp bucket has name "Comp"' do
      comp_bucket = result.buckets.find { |b| b.bucket_type == :comp }
      expect(comp_bucket.name).to eq('Comp')
    end

    it 'counts comp tickets in comp_count on summary' do
      expect(result.comp_count).to eq(3)
    end

    it 'comp bucket has actual_gross = 0' do
      comp_bucket = result.buckets.find { |b| b.bucket_type == :comp }
      expect(comp_bucket.actual_gross).to eq(BigDecimal('0'))
    end

    it 'comp bucket is always the last bucket' do
      expect(result.buckets.last.bucket_type).to eq(:comp)
    end

    it 'does not count comp tickets in total_paid' do
      expect(result.total_paid).to eq(0)
    end

    it 'comp tickets contribute to capacity_utilization_pct (3/100 = 3.0%)' do
      expect(result.capacity_utilization_pct).to eq(3.0)
    end
  end

  # ---------------------------------------------------------------------------
  # #compute — zero-revenue ticket class
  # ---------------------------------------------------------------------------
  describe '#compute with zero-revenue ticket class' do
    let(:production)  { make_production(capacity: 100) }
    let!(:free_tc)    { make_ticket_class(production, price: 0.0, code: 'ZRV', comp: false) }
    let!(:perf)       { make_performance(production) }

    before do
      make_allocation(perf, free_tc)
      make_order_with_line_item(perf, free_tc, count: 4)
    end

    subject(:result) { described_class.new(production).compute }

    it 'creates a zero_rev bucket of type :zero_rev' do
      expect(result.buckets.find { |b| b.bucket_type == :zero_rev }).not_to be_nil
    end

    it 'zero_rev bucket has name "No Revenue"' do
      expect(result.buckets.find { |b| b.bucket_type == :zero_rev }.name).to eq('No Revenue')
    end

    it 'zero_rev bucket has paid_count = number of free tickets' do
      expect(result.buckets.find { |b| b.bucket_type == :zero_rev }.paid_count).to eq(4)
    end

    it 'zero_rev tickets do NOT contribute to total_paid' do
      expect(result.total_paid).to eq(0)
    end

    it 'zero_rev tickets contribute to capacity_utilization_pct (4/100 = 4.0%)' do
      expect(result.capacity_utilization_pct).to eq(4.0)
    end
  end

  # ---------------------------------------------------------------------------
  # Mixed bucket types: paid + zero_rev + comp
  # ---------------------------------------------------------------------------
  describe '#compute bucket ordering with mixed types' do
    let(:production)  { make_production(capacity: 200) }
    let!(:paid_tc)    { make_ticket_class(production, price: 25.0, code: 'PAD') }
    let!(:comp_tc)    { make_ticket_class(production, price: 0.0, code: 'CMX', comp: true) }
    let!(:free_tc)    { make_ticket_class(production, price: 0.0, code: 'ZRX', comp: false) }
    let!(:perf)       { make_performance(production) }

    before do
      make_allocation(perf, paid_tc)
      make_allocation(perf, comp_tc)
      make_allocation(perf, free_tc)
      make_order_with_line_item(perf, paid_tc, count: 2)
      make_order_with_line_item(perf, comp_tc, count: 1)
      make_order_with_line_item(perf, free_tc, count: 3)
    end

    subject(:result) { described_class.new(production).compute }

    it 'has 3 buckets total (singleton, zero_rev, comp)' do
      expect(result.buckets.size).to eq(3)
    end

    it 'the comp bucket is always last' do
      expect(result.buckets.last.bucket_type).to eq(:comp)
    end

    it 'zero_rev bucket precedes comp bucket' do
      types = result.buckets.map(&:bucket_type)
      expect(types.index(:zero_rev)).to be < types.index(:comp)
    end

    it 'paid singleton is first (highest avg price)' do
      expect(result.buckets.first.bucket_type).to eq(:singleton)
    end
  end

  # ---------------------------------------------------------------------------
  # Ticketing fee deducted from entry_price
  # ---------------------------------------------------------------------------
  describe '#compute effective_class_price with ticketing_fee' do
    let(:production)  { make_production }
    let!(:fee_tc)     { make_ticket_class(production, price: 30.0, code: 'FEE', fee: 2.0) }
    let!(:perf)       { make_performance(production) }

    before do
      make_allocation(perf, fee_tc)
      make_order_with_line_item(perf, fee_tc, count: 1)
    end

    it 'subtracts ticketing_fee from entry_price (30.0 - 2.0 = 28.0)' do
      result = described_class.new(production).compute
      bucket = result.buckets.find { |b| b.ticket_class_ids.include?(fee_tc.id) }
      expect(bucket.entry_price).to eq(BigDecimal('28.0'))
    end

    it 'avg_paid_price uses the net (price - fee) amount' do
      result = described_class.new(production).compute
      bucket = result.buckets.find { |b| b.ticket_class_ids.include?(fee_tc.id) }
      expect(bucket.avg_paid_price).to eq(BigDecimal('28.0'))
    end
  end

  # ---------------------------------------------------------------------------
  # Royalty fallback when ticket_price == 0
  # ---------------------------------------------------------------------------
  describe '#compute effective price with royalty_amount fallback (ticket_price=0)' do
    let(:production)  { make_production(capacity: 50) }
    let!(:roy_tc)     { make_ticket_class(production, price: 0.0, code: 'ROY', royalty: 15.0, comp: false) }
    let!(:perf)       { make_performance(production) }

    before do
      make_allocation(perf, roy_tc)
      make_order_with_line_item(perf, roy_tc, count: 2)
    end

    it 'uses royalty_amount as entry_price when ticket_price == 0' do
      result = described_class.new(production).compute
      bucket = result.buckets.find { |b| b.bucket_type == :singleton }
      expect(bucket).not_to be_nil
      expect(bucket.entry_price).to eq(BigDecimal('15.0'))
    end

    it 'actual_gross = royalty_amount * count (15 * 2 = 30)' do
      result = described_class.new(production).compute
      bucket = result.buckets.find { |b| b.bucket_type == :singleton }
      expect(bucket.actual_gross).to eq(BigDecimal('30.0'))
    end
  end

  # ---------------------------------------------------------------------------
  # price_override behavior: TicketLineItem#check_price_override clears the
  # override to nil for non-Donation ticket types, so price_override is only
  # effective for split-generated Donation tickets.
  # ---------------------------------------------------------------------------
  describe '#compute with price_override on a non-Donation ticket' do
    let(:production)  { make_production(capacity: 50) }
    # NOTE: ticket_type is 'Fixed', not 'Donation'
    let!(:paid_tc)    { make_ticket_class(production, price: 50.0, code: 'DON') }
    let!(:perf)       { make_performance(production) }

    before do
      make_allocation(perf, paid_tc)
      order = TicketOrder.create!(
        status: Order::NEW, performance: perf,
        address: FactoryBot.create(:address),
        payment_type: FactoryBot.create(:cash_payment_type)
      )
      # price_override=30 is set, but TicketLineItem#check_price_override (line 69-70)
      # clears it to nil for non-split, non-Donation tickets:
      #   self.price_override = nil if !generated_from_split? && (!ticket_type.eql?('Donation'))
      # So the override is wiped before saving.
      TicketLineItem.create!(order: order, ticket_class: paid_tc, ticket_count: 1, price_override: 30.0)
      order.update_column(:status, Order::PROCESSED)
    end

    subject(:result) { described_class.new(production).compute }

    # SUSPECTED BUG (app/models/line_items/ticket_line_item.rb:69-70):
    # check_price_override silently discards price_override for non-Donation, non-split tickets.
    # The effective_price logic in TicketRevenueAnalysis CAN use override (elsif branch),
    # but the override column is always nil for Fixed-type tickets, so it never fires.
    it 'price_override is silently discarded for Fixed-type tickets (override=nil after save)' do
      bucket = result.buckets.first
      # Override was cleared by check_price_override → falls through to else → uses ticket_price=50
      expect(bucket.avg_paid_price).to eq(BigDecimal('50.0'))
    end
  end

  # ---------------------------------------------------------------------------
  # Allocation cap hit
  # ---------------------------------------------------------------------------
  describe '#compute allocation_cap_hit' do
    let(:production)  { make_production(capacity: 100) }
    let!(:tc)         { make_ticket_class(production, price: 20.0, code: 'CAP') }
    let!(:perf)       { make_performance(production) }

    before do
      make_allocation(perf, tc, limit: 2)
      make_order_with_line_item(perf, tc, count: 2)  # sold == limit
    end

    it 'sets allocation_cap_hit to true when sold == allocation limit' do
      result = described_class.new(production).compute
      bucket = result.buckets.find { |b| b.ticket_class_ids.include?(tc.id) }
      expect(bucket.allocation_cap_hit).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # Fallback allocation when no ticket_limit
  # ---------------------------------------------------------------------------
  describe '#compute fallback allocation (no ticket_limit)' do
    let(:production)  { make_production(capacity: 50) }
    let!(:tc)         { make_ticket_class(production, price: 20.0, code: 'FAL') }
    let!(:perf)       { make_performance(production) }

    before do
      make_allocation(perf, tc, limit: nil)
      make_order_with_line_item(perf, tc, count: 5)
    end

    it 'uses production.capacity * perf_count as fallback (50 * 1 = 50)' do
      result = described_class.new(production).compute
      bucket = result.buckets.find { |b| b.ticket_class_ids.include?(tc.id) }
      expect(bucket.bucket_allocation).to eq(50)
    end

    it 'sets allocation_from_limit to false' do
      result = described_class.new(production).compute
      bucket = result.buckets.find { |b| b.ticket_class_ids.include?(tc.id) }
      expect(bucket.allocation_from_limit).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # Dynamic pricing: shiftable allocations → dynamic bucket
  # ---------------------------------------------------------------------------
  describe '#compute with dynamic pricing (shiftable allocations)' do
    let(:production)  { make_production(capacity: 200) }
    let!(:tc_low)     { make_ticket_class(production, price: 20.0, code: 'DYL') }
    let!(:tc_high)    { make_ticket_class(production, price: 40.0, code: 'DYH') }
    let!(:perf)       { make_performance(production) }

    before do
      make_allocation(perf, tc_low, shiftable: true, shift_to_code: 'DYH')
      make_allocation(perf, tc_high)
      make_order_with_line_item(perf, tc_low, count: 2)
      make_order_with_line_item(perf, tc_high, count: 3)
    end

    subject(:result) { described_class.new(production).compute }

    it 'groups LOW and HIGH into a single dynamic bucket' do
      dynamic = result.buckets.select { |b| b.bucket_type == :dynamic }
      expect(dynamic.size).to eq(1)
    end

    it 'dynamic bucket includes both class codes' do
      bucket = result.buckets.find { |b| b.bucket_type == :dynamic }
      expect(bucket.class_codes).to include('DYL', 'DYH')
    end

    it 'entry_price is the minimum price (DYL=20)' do
      bucket = result.buckets.find { |b| b.bucket_type == :dynamic }
      expect(bucket.entry_price).to eq(BigDecimal('20.0'))
    end

    it 'paid_count sums both classes (2 + 3 = 5)' do
      bucket = result.buckets.find { |b| b.bucket_type == :dynamic }
      expect(bucket.paid_count).to eq(5)
    end

    it 'dynamic_lift_dollars = actual_gross - flat_base_gross (160 - 100 = 60)' do
      bucket = result.buckets.find { |b| b.bucket_type == :dynamic }
      expect(bucket.dynamic_lift_dollars).to eq(BigDecimal('60.0'))
    end

    it 'dynamic_lift_pct = 60 / 100 * 100 = 60%' do
      bucket = result.buckets.find { |b| b.bucket_type == :dynamic }
      expect(bucket.dynamic_lift_pct).to be_within(0.01).of(60.0)
    end

    it 'summary total_dynamic_lift_dollars = 60' do
      expect(result.total_dynamic_lift_dollars).to eq(BigDecimal('60.0'))
    end

    it 'summary total_dynamic_lift_pct = 60.0' do
      expect(result.total_dynamic_lift_pct).to be_within(0.01).of(60.0)
    end
  end

  # ---------------------------------------------------------------------------
  # Caching
  # ---------------------------------------------------------------------------
  describe '#compute caching' do
    let(:production)  { make_production }
    let!(:tc)         { make_ticket_class(production, price: 25.0, code: 'CC1') }
    let!(:perf)       { make_performance(production) }

    before do
      make_allocation(perf, tc)
      make_order_with_line_item(perf, tc, count: 1)
    end

    it 'returns the same result on repeated calls' do
      analysis = described_class.new(production)
      r1 = analysis.compute
      r2 = analysis.compute
      expect(r1.total_paid).to eq(r2.total_paid)
    end

    it 'returns equal results on cache hit' do
      analysis = described_class.new(production)
      expect(analysis.compute).to eq(analysis.compute)
    end
  end

  # ---------------------------------------------------------------------------
  # special_offer_usage empty when no special offers
  # ---------------------------------------------------------------------------
  describe '#compute special_offer_usage' do
    let(:production)  { make_production }
    let!(:tc)         { make_ticket_class(production, price: 30.0, code: 'SOU') }
    let!(:perf)       { make_performance(production) }

    before do
      make_allocation(perf, tc)
      make_order_with_line_item(perf, tc, count: 1)
    end

    it 'returns an empty array when no special offers exist' do
      result = described_class.new(production).compute
      expect(result.special_offer_usage).to eq([])
    end
  end

  # ---------------------------------------------------------------------------
  # ladder_distribution
  # ---------------------------------------------------------------------------
  describe '#compute ladder_distribution' do
    let(:production)  { make_production }
    let!(:tc)         { make_ticket_class(production, price: 25.0, code: 'LAD') }
    let!(:perf)       { make_performance(production) }

    before do
      make_allocation(perf, tc)
      make_order_with_line_item(perf, tc, count: 2)
      make_order_with_line_item(perf, tc, count: 3)
    end

    subject(:result) { described_class.new(production).compute }

    it 'ladder_distribution is a Hash' do
      expect(result.buckets.first.ladder_distribution).to be_a(Hash)
    end

    it 'groups tickets by rounded price (5 tickets at 25.0 → one entry)' do
      expect(result.buckets.first.ladder_distribution[25.0]).to eq(5)
    end
  end

  # ---------------------------------------------------------------------------
  # Private method: #union_find_buckets
  # ---------------------------------------------------------------------------
  describe '#union_find_buckets' do
    let(:production) { make_production }
    let(:analysis)   { described_class.new(production) }

    it 'groups two connected nodes into one component' do
      result = analysis.send(:union_find_buckets, [1, 2, 3], [[1, 2]])
      expect(result.sort_by { |g| g.min }.size).to eq(2)
    end

    it 'returns each id as its own group when no edges' do
      result = analysis.send(:union_find_buckets, [1, 2, 3], [])
      expect(result.size).to eq(3)
      result.each { |g| expect(g.size).to eq(1) }
    end

    it 'handles a transitive chain (1-2, 2-3) → all in one group' do
      result = analysis.send(:union_find_buckets, [1, 2, 3], [[1, 2], [2, 3]])
      expect(result.size).to eq(1)
      expect(result.first.sort).to eq([1, 2, 3])
    end

    it 'returns empty array for empty input' do
      expect(analysis.send(:union_find_buckets, [], [])).to eq([])
    end
  end

  # ---------------------------------------------------------------------------
  # Private method: #effective_class_price
  # ---------------------------------------------------------------------------
  describe '#effective_class_price' do
    let(:production) { make_production }
    let(:analysis)   { described_class.new(production) }

    it 'returns ticket_price - ticketing_fee for a normal class' do
      tc = make_ticket_class(production, price: 30.0, fee: 2.0)
      expect(analysis.send(:effective_class_price, tc)).to eq(BigDecimal('28.0'))
    end

    it 'uses royalty_amount when ticket_price == 0 and royalty is present' do
      tc = make_ticket_class(production, price: 0.0, royalty: 12.0, fee: 0.0)
      expect(analysis.send(:effective_class_price, tc)).to eq(BigDecimal('12.0'))
    end

    it 'returns 0.0 when ticket_price == 0 and no royalty' do
      tc = make_ticket_class(production, price: 0.0)
      expect(analysis.send(:effective_class_price, tc)).to eq(BigDecimal('0.0'))
    end

    it 'subtracts ticketing_fee from royalty_amount when price is 0' do
      tc = make_ticket_class(production, price: 0.0, royalty: 12.0, fee: 2.0)
      expect(analysis.send(:effective_class_price, tc)).to eq(BigDecimal('10.0'))
    end
  end

  # ---------------------------------------------------------------------------
  # Private method: #compute_allocation
  # ---------------------------------------------------------------------------
  describe '#compute_allocation' do
    let(:analysis) { described_class.new(make_production) }

    it 'returns [fallback, false] when no allocation data for tc_ids' do
      alloc, from_limit = analysis.send(:compute_allocation, [99], {}, 500)
      expect(alloc).to eq(500)
      expect(from_limit).to be false
    end

    it 'returns fallback when all limits are zero or missing' do
      data = { 1 => { total_limit: 0, has_any_limit: false } }
      alloc, from_limit = analysis.send(:compute_allocation, [1], data, 200)
      expect(alloc).to eq(200)
      expect(from_limit).to be false
    end

    it 'sums limits when multiple tc_ids have limits' do
      data = { 1 => { total_limit: 30, has_any_limit: true },
               2 => { total_limit: 20, has_any_limit: true } }
      alloc, from_limit = analysis.send(:compute_allocation, [1, 2], data, 500)
      expect(alloc).to eq(50)
      expect(from_limit).to be true
    end

    it 'falls back when from_limit is true but bucket_alloc is 0 (total_limit=0)' do
      data = { 1 => { total_limit: 0, has_any_limit: true } }
      alloc, _from_limit = analysis.send(:compute_allocation, [1], data, 300)
      expect(alloc).to eq(300)
    end
  end

  # ---------------------------------------------------------------------------
  # Private method: #class_breakdown_for
  # ---------------------------------------------------------------------------
  describe '#class_breakdown_for' do
    let(:production) { make_production }
    let(:analysis)   { described_class.new(production) }

    it 'returns an array of hashes with class breakdown' do
      tc = make_ticket_class(production, price: 20.0, code: 'BDA')
      rows = [{ tc_id: tc.id, count: 3, price: BigDecimal('20.0') }]
      result = analysis.send(:class_breakdown_for, rows, 3, { tc.id => tc })
      expect(result.first[:class_code]).to eq('BDA')
      expect(result.first[:ticket_count]).to eq(3)
      expect(result.first[:avg_price]).to eq(BigDecimal('20.0'))
      expect(result.first[:gross]).to eq(BigDecimal('60.0'))
      expect(result.first[:pct_of_bucket]).to eq(100.0)
    end

    it 'sorts by avg_price descending' do
      tc1 = make_ticket_class(production, price: 10.0, code: 'BDB')
      tc2 = make_ticket_class(production, price: 30.0, code: 'BDC')
      rows = [
        { tc_id: tc1.id, count: 2, price: BigDecimal('10.0') },
        { tc_id: tc2.id, count: 1, price: BigDecimal('30.0') }
      ]
      result = analysis.send(:class_breakdown_for, rows, 3, { tc1.id => tc1, tc2.id => tc2 })
      expect(result.first[:class_code]).to eq('BDC')
    end
  end

  # ---------------------------------------------------------------------------
  # Private method: #entry_price_for_bucket
  # ---------------------------------------------------------------------------
  describe '#entry_price_for_bucket' do
    let(:production) { make_production }
    let(:analysis)   { described_class.new(production) }

    it 'returns the minimum effective price in the bucket' do
      tc1 = make_ticket_class(production, price: 20.0, code: 'EP1')
      tc2 = make_ticket_class(production, price: 40.0, code: 'EP2')
      result = analysis.send(:entry_price_for_bucket, [tc1.id, tc2.id], [], { tc1.id => tc1, tc2.id => tc2 })
      expect(result).to eq(BigDecimal('20.0'))
    end

    it 'returns BigDecimal(0) for empty tc_ids' do
      expect(analysis.send(:entry_price_for_bucket, [], [], {})).to eq(BigDecimal('0'))
    end
  end
end
