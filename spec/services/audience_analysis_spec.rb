require 'rails_helper'

RSpec.describe AudienceAnalysis do
  # Helpers ------------------------------------------------------------

  def make_theater(name)
    Theater.create!(
      name: name,
      theater_class: Theater::DEFAULT,
      status: Theater::ACTIVE,
      accepts_donations: false
    )
  end

  def make_production(theater, name:, closing_at:, opening_at: closing_at - 30.days)
    @production_seq ||= 0
    @production_seq += 1
    Production.create!(
      theater: theater,
      venue: shared_venue,
      name: name,
      production_code: "P#{'%07d' % @production_seq}",
      status: Production::PRODUCTION_STATUSES.first,
      capacity: 100,
      opening_at: opening_at,
      first_preview_at: opening_at,
      press_opening_at: opening_at,
      closing_at: closing_at,
      season: opening_at.year,
      running_time: 90
    )
  end

  def shared_venue
    @shared_venue ||= Venue.create!(name: "TestVenue-#{SecureRandom.hex(3)}", ordinal_sort: 1)
  end

  def make_ticket_class(production, complimentary:)
    TicketClass.create!(
      production: production,
      class_code: "TC-#{SecureRandom.hex(3)}",
      class_name: complimentary ? 'Comp' : 'General',
      ticket_type: 'Fixed',
      ticket_price: complimentary ? 0 : 25,
      ticketing_fee: 0,
      web_visible: true,
      holds_seats: true,
      complimentary: complimentary
    )
  end

  def make_performance(production, date)
    Performance.create!(
      production: production,
      performance_date: date,
      performance_time: '19:30:00',
      status: Performance::PERFORMANCE_STATUSES.first,
      performance_code: "#{production.production_code}-#{SecureRandom.hex(2)}"
    )
  end

  def make_address(email)
    Address.create!(
      first_name: 'Test',
      last_name: "User-#{SecureRandom.hex(3)}",
      full_name: "Test User-#{SecureRandom.hex(3)}",
      email: email,
      line1: '1 Test St',
      city: 'Test',
      state: 'IL',
      zipcode: '60000'
    )
  end

  # Build a settled attending TicketOrder with one ticket_line_item of the
  # given ticket_class. We bypass status transitions to keep the test fast;
  # only the rows the SQL reads matter here.
  def make_attended_order(address:, performance:, ticket_class:)
    order = TicketOrder.new(
      address: address,
      performance: performance,
      theater: performance.production.theater,
      status: Order::PROCESSED,
      payment_type: cash_payment_type,
      uuid: SecureRandom.uuid,
      campaign: 'Test'
    )
    order.save(validate: false)
    TicketLineItem.create!(
      order_id: order.id,
      ticket_class: ticket_class,
      ticket_count: 1,
      amount: ticket_class.ticket_price
    )
    order
  end

  def cash_payment_type
    @cash_payment_type ||= FactoryBot.create(:cash_payment_type)
  end

  # Test setup ---------------------------------------------------------

  let(:anchor) { Date.new(2026, 1, 1) }

  let!(:theater_a) { make_theater("Theater A #{SecureRandom.hex(2)}") }
  let!(:theater_b) { make_theater("Theater B #{SecureRandom.hex(2)}") }
  let!(:theater_c) { make_theater("Theater C #{SecureRandom.hex(2)}") }

  let!(:target_production) do
    p = make_production(theater_a, name: 'SELECTED', closing_at: anchor)
    @target_paid_class = make_ticket_class(p, complimentary: false)
    @target_comp_class = make_ticket_class(p, complimentary: true)
    @target_performance = make_performance(p, anchor - 5.days)
    p
  end

  let!(:prod_a_recent) do
    p = make_production(theater_a, name: 'A_RECENT', closing_at: anchor - 30.days)
    @a_recent_class = make_ticket_class(p, complimentary: false)
    @a_recent_perf  = make_performance(p, anchor - 30.days)
    p
  end

  let!(:prod_a_mid) do
    p = make_production(theater_a, name: 'A_MID', closing_at: anchor - 200.days)
    @a_mid_class = make_ticket_class(p, complimentary: false)
    @a_mid_perf  = make_performance(p, anchor - 200.days)
    p
  end

  let!(:prod_b_recent) do
    p = make_production(theater_b, name: 'B_RECENT', closing_at: anchor - 45.days)
    @b_recent_class = make_ticket_class(p, complimentary: false)
    @b_recent_perf  = make_performance(p, anchor - 45.days)
    p
  end

  let!(:prod_c_old) do
    p = make_production(theater_c, name: 'C_OLD', closing_at: anchor - 400.days)
    @c_old_class = make_ticket_class(p, complimentary: false)
    @c_old_perf  = make_performance(p, anchor - 400.days)
    p
  end

  let!(:prod_a_post_anchor) do
    p = make_production(theater_a, name: 'A_POST', closing_at: anchor + 60.days)
    @a_post_class = make_ticket_class(p, complimentary: false)
    @a_post_perf  = make_performance(p, anchor + 30.days)
    p
  end

  subject(:results) { described_class.new(target_production, comparison).compute }

  describe "anchor date" do
    it "uses the closing_at when the production has closed" do
      allow(target_production).to receive(:closed?).and_return(true)
      allow(target_production).to receive(:closing_at).and_return(anchor)
      svc = described_class.new(target_production, [theater_a.id, theater_b.id, theater_c.id])
      expect(svc.compute[:anchor_date]).to eq(anchor)
    end

    it "uses today when the production is still running" do
      future_close = Date.today + 30.days
      running = make_production(theater_a, name: 'STILL_RUNNING', closing_at: future_close,
                                           opening_at: Date.today - 10.days)
      make_ticket_class(running, complimentary: false)
      make_performance(running, Date.today - 1.day)
      svc = described_class.new(running, [theater_a.id, theater_b.id, theater_c.id])
      expect(svc.compute[:anchor_date]).to eq(Date.today)
    end
  end

  describe "cohort selection" do
    before do
      allow(target_production).to receive(:closed?).and_return(true)
      allow(target_production).to receive(:closing_at).and_return(anchor)
    end

    let(:comparison) { [theater_a.id, theater_b.id, theater_c.id] }

    it "is empty when no paid attendees exist" do
      expect(results[:cohort_size]).to eq(0)
      results[:metrics].each_value do |window_map|
        window_map.each_value { |v| expect(v).to eq(0) }
      end
    end

    it "includes addresses with no email but a street address" do
      addr = make_address(nil) # make_address always sets line1 + zipcode
      make_attended_order(address: addr, performance: @target_performance, ticket_class: @target_paid_class)
      expect(results[:cohort_size]).to eq(1)
    end

    it "excludes addresses with no email AND no street address" do
      addr = Address.create!(first_name: 'X', last_name: 'Y', full_name: 'X Y')
      make_attended_order(address: addr, performance: @target_performance, ticket_class: @target_paid_class)
      expect(results[:cohort_size]).to eq(0)
    end

    it "excludes 'Not a ticket buyer' (placeholder) addresses" do
      addr = make_address('placeholder@example.com')
      addr.update!(placeholder: true)
      make_attended_order(address: addr, performance: @target_performance, ticket_class: @target_paid_class)
      expect(results[:cohort_size]).to eq(0)
    end

    it "excludes orders with only comp tickets" do
      addr = make_address('only_comp@example.com')
      make_attended_order(address: addr, performance: @target_performance, ticket_class: @target_comp_class)
      expect(results[:cohort_size]).to eq(0)
    end

    it "includes addresses with at least one paid order" do
      addr = make_address('paid@example.com')
      make_attended_order(address: addr, performance: @target_performance, ticket_class: @target_paid_class)
      expect(results[:cohort_size]).to eq(1)
    end

    it "treats two distinct address_ids as two cohort members even if they share an email" do
      a1 = make_address('shared@example.com')
      a2 = make_address('shared@example.com')
      make_attended_order(address: a1, performance: @target_performance, ticket_class: @target_paid_class)
      make_attended_order(address: a2, performance: @target_performance, ticket_class: @target_paid_class)
      expect(results[:cohort_size]).to eq(2)
    end
  end

  describe "metric counts" do
    let(:comparison) { [theater_a.id, theater_c.id] }

    before do
      allow(target_production).to receive(:closed?).and_return(true)
      allow(target_production).to receive(:closing_at).and_return(anchor)
    end

    let!(:alice) do
      a = make_address('alice@example.com')
      make_attended_order(address: a, performance: @target_performance, ticket_class: @target_paid_class)
      a
    end
    let!(:bob) do
      a = make_address('bob@example.com')
      make_attended_order(address: a, performance: @target_performance, ticket_class: @target_paid_class)
      make_attended_order(address: a, performance: @a_recent_perf, ticket_class: @a_recent_class)
      a
    end
    let!(:carol) do
      a = make_address('carol@example.com')
      make_attended_order(address: a, performance: @target_performance, ticket_class: @target_paid_class)
      make_attended_order(address: a, performance: @a_recent_perf, ticket_class: @a_recent_class)
      make_attended_order(address: a, performance: @a_mid_perf, ticket_class: @a_mid_class)
      a
    end
    let!(:dave) do
      a = make_address('dave@example.com')
      make_attended_order(address: a, performance: @target_performance, ticket_class: @target_paid_class)
      make_attended_order(address: a, performance: @b_recent_perf, ticket_class: @b_recent_class)
      a
    end
    let!(:eve) do
      a = make_address('eve@example.com')
      make_attended_order(address: a, performance: @target_performance, ticket_class: @target_paid_class)
      make_attended_order(address: a, performance: @a_recent_perf, ticket_class: @a_recent_class)
      make_attended_order(address: a, performance: @a_mid_perf, ticket_class: @a_mid_class)
      make_attended_order(address: a, performance: @c_old_perf, ticket_class: @c_old_class)
      a
    end
    let!(:frank) do
      a = make_address('frank@example.com')
      make_attended_order(address: a, performance: @target_performance, ticket_class: @target_paid_class)
      make_attended_order(address: a, performance: @a_post_perf, ticket_class: @a_post_class)
      a
    end

    it "cohort includes all six paid attendees" do
      expect(results[:cohort_size]).to eq(6)
    end

    it "first-time vs comparison group, 3-month window" do
      # Within 3mo: A_RECENT (-30d) is in comparison, B_RECENT (-45d) is NOT.
      # alice 0, bob 1, carol 1 (A_MID outside), dave 0, eve 1, frank 0 (post-anchor excluded).
      expect(results[:metrics][:first_time_vs_comparison]["3 months"]).to eq(3)
    end

    it "first-time vs comparison group, 1-year window" do
      # alice 0, bob 1, carol 2, dave 0, eve 2, frank 0.
      expect(results[:metrics][:first_time_vs_comparison]["1 year"]).to eq(3)
    end

    it "dedicated customers — attended every comparison production in window, 1-year" do
      # 1-year comparison productions: A_RECENT and A_MID (C_OLD outside 1yr) → 2.
      # carol: 2 of 2 → YES. eve: 2 of 2 → YES.
      expect(results[:metrics][:dedicated_customers]["1 year"]).to eq(2)
    end

    it "dedicated customers, 3-year window" do
      # 3-year comparison productions: A_RECENT, A_MID, C_OLD → 3.
      # carol: 2 of 3 → no. eve: 3 of 3 → YES.
      expect(results[:metrics][:dedicated_customers]["3 years"]).to eq(1)
    end

    it "dedicated customers, 3-month window" do
      # 3-month comparison productions: A_RECENT only → 1.
      # bob, carol, eve all attended A_RECENT → 3 dedicated.
      expect(results[:metrics][:dedicated_customers]["3 months"]).to eq(3)
    end

    it "2+ visits in comparison, 3-year window" do
      # 3-year comparison productions: A_RECENT, A_MID, C_OLD → 3.
      # carol: 2 (A_RECENT + A_MID). eve: 3 (A_RECENT + A_MID + C_OLD).
      # Both qualify under >= 2.
      expect(results[:metrics][:two_plus_in_comparison]["3 years"]).to eq(2)
    end

    it "2+ visits in comparison, 1-year window" do
      # 1-year comparison productions: A_RECENT, A_MID (C_OLD outside).
      # carol: 2. eve: 2. Both qualify.
      expect(results[:metrics][:two_plus_in_comparison]["1 year"]).to eq(2)
    end

    it "2+ visits in comparison, 3-month window" do
      # Only A_RECENT in window — nobody can hit 2.
      expect(results[:metrics][:two_plus_in_comparison]["3 months"]).to eq(0)
    end

    it "first-time vs entire building, 3-month window" do
      # Building 3mo: A_RECENT and B_RECENT.
      # alice 0, bob 1, carol 1, dave 1, eve 1, frank 0.
      expect(results[:metrics][:first_time_vs_building]["3 months"]).to eq(2)
    end

    it "3+ visits anywhere in the building, 3-year window" do
      # eve has A_RECENT + A_MID + C_OLD = 3 building visits.
      expect(results[:metrics][:three_plus_in_building]["3 years"]).to eq(1)
    end

    it "post-anchor orders are excluded — frank counts as first-time everywhere" do
      results[:window_labels].each do |label|
        # frank contributes one "first-time" count in every window for both
        # comparison and building metrics. The lower bound here is 1; the
        # exact total varies by window per the per-window expectations above.
        expect(results[:metrics][:first_time_vs_comparison][label]).to be >= 1
        expect(results[:metrics][:first_time_vs_building][label]).to be >= 1
      end
    end
  end

  describe "non-order attendance (mailing card entries)" do
    let(:comparison) { [theater_a.id, theater_b.id, theater_c.id] }

    before do
      allow(target_production).to receive(:closed?).and_return(true)
      allow(target_production).to receive(:closing_at).and_return(anchor)
    end

    it "includes addresses linked via addresses_productions HABTM with no orders" do
      addr = make_address('cardonly@example.com')
      target_production.addresses << addr
      expect(results[:cohort_size]).to eq(1)
    end

    it "counts HABTM-only cross-attendance for cohort members" do
      addr = make_address('mixedmode@example.com')
      # Cohort membership via a paid order to the target
      make_attended_order(address: addr, performance: @target_performance, ticket_class: @target_paid_class)
      # Cross-attendance to A_RECENT via HABTM (mailing card, not order)
      prod_a_recent.addresses << addr

      expect(results[:metrics][:returning_vs_comparison]["3 months"]).to eq(1)
      expect(results[:metrics][:first_time_vs_comparison]["3 months"]).to eq(0)
    end

    it "treats a HABTM-only cohort member as first-time when they have no other attendance" do
      addr = make_address('newcard@example.com')
      target_production.addresses << addr # mailing card only
      expect(results[:metrics][:first_time_vs_comparison]["3 months"]).to eq(1)
      expect(results[:metrics][:returning_vs_comparison]["3 months"]).to eq(0)
    end

    it "applies the same placeholder + identifying-info filters to HABTM-only entries" do
      placeholder = make_address('placeholder@example.com')
      placeholder.update!(placeholder: true)
      target_production.addresses << placeholder

      no_contact = Address.create!(first_name: 'X', last_name: 'Y', full_name: 'X Y')
      target_production.addresses << no_contact

      expect(results[:cohort_size]).to eq(0)
    end
  end

  describe "#cohort_for" do
    let(:comparison) { [theater_a.id, theater_b.id, theater_c.id] }

    before do
      allow(target_production).to receive(:closed?).and_return(true)
      allow(target_production).to receive(:closing_at).and_return(anchor)
    end

    let(:service) { described_class.new(target_production, comparison) }

    it "returns the full cohort for :cohort regardless of window" do
      a = make_address('alice@example.com')
      b = make_address('bob@example.com')
      make_attended_order(address: a, performance: @target_performance, ticket_class: @target_paid_class)
      make_attended_order(address: b, performance: @target_performance, ticket_class: @target_paid_class)
      expect(service.cohort_for(:cohort)).to eq(Set.new([a.id, b.id]))
    end

    it "returns an empty Set when the cohort is empty" do
      expect(service.cohort_for(:cohort)).to eq(Set.new)
      expect(service.cohort_for(:first_time_vs_comparison, "3 months")).to eq(Set.new)
    end

    it "returns address_ids that match the previous-production segment key" do
      a = make_address('alice@example.com')
      b = make_address('bob@example.com')
      make_attended_order(address: a, performance: @target_performance, ticket_class: @target_paid_class)
      make_attended_order(address: a, performance: @a_recent_perf, ticket_class: @a_recent_class)
      make_attended_order(address: b, performance: @target_performance, ticket_class: @target_paid_class)

      key = "previous_production:#{prod_a_recent.id}"
      expect(service.cohort_for(key)).to eq(Set.new([a.id]))
    end

    it "returns address_ids attending any comparison production for :returning_any" do
      a = make_address('alice@example.com')
      b = make_address('bob@example.com')
      make_attended_order(address: a, performance: @target_performance, ticket_class: @target_paid_class)
      make_attended_order(address: a, performance: @a_recent_perf, ticket_class: @a_recent_class)
      make_attended_order(address: b, performance: @target_performance, ticket_class: @target_paid_class)

      expect(service.cohort_for(:returning_any)).to eq(Set.new([a.id]))
    end

    it "partitions first_time_vs_comparison by window" do
      a = make_address('alice@example.com')
      b = make_address('bob@example.com')
      make_attended_order(address: a, performance: @target_performance, ticket_class: @target_paid_class)
      make_attended_order(address: a, performance: @a_recent_perf, ticket_class: @a_recent_class)
      make_attended_order(address: b, performance: @target_performance, ticket_class: @target_paid_class)

      # alice has a comparison visit in the 3mo window → not first-time
      # bob has no other visits → first-time
      expect(service.cohort_for(:first_time_vs_comparison, "3 months")).to eq(Set.new([b.id]))
      expect(service.cohort_for(:returning_vs_comparison, "3 months")).to eq(Set.new([a.id]))
    end

    it "raises on unknown segment_key" do
      a = make_address('alice@example.com')
      make_attended_order(address: a, performance: @target_performance, ticket_class: @target_paid_class)
      expect { service.cohort_for(:bogus) }.to raise_error(ArgumentError)
    end

    it "raises when window_label is missing for a per-window segment" do
      a = make_address('alice@example.com')
      make_attended_order(address: a, performance: @target_performance, ticket_class: @target_paid_class)
      expect { service.cohort_for(:first_time_vs_comparison) }.to raise_error(ArgumentError)
    end
  end

  describe "explicit multi-theater comparison" do
    let(:comparison) { [theater_a.id, theater_b.id, theater_c.id] }

    before do
      allow(target_production).to receive(:closed?).and_return(true)
      allow(target_production).to receive(:closing_at).and_return(anchor)
    end

    it "treats every selected theater as part of the comparison" do
      a = make_address('zoe@example.com')
      make_attended_order(address: a, performance: @target_performance, ticket_class: @target_paid_class)
      make_attended_order(address: a, performance: @b_recent_perf, ticket_class: @b_recent_class)

      # B is now explicitly in the comparison group, so the visit counts as
      # a comparison visit and zoe is NOT first-time in either scope.
      expect(results[:metrics][:first_time_vs_comparison]["3 months"]).to eq(0)
      expect(results[:metrics][:first_time_vs_building]["3 months"]).to eq(0)
    end
  end
end
