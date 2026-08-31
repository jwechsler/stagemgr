require 'rails_helper'

RSpec.describe SyncResourcedTicketClassJob do
  let(:venue_a) { FactoryBot.create(:venue) }
  let(:venue_b) { FactoryBot.create(:venue) }
  let(:other_venue) { FactoryBot.create(:venue) }
  let(:theater) { FactoryBot.create(:theater) }
  let(:show_date) { Date.current + 30.days }

  def production_in(venue, **attrs)
    FactoryBot.create(:production, venue: venue, theater: theater, running_time: 120, **attrs)
  end

  # See the note in resourced_ticket_class_spec: performance_time is a plain TIME
  # column, so a bare (system zone) Time is what stores the hour asked for.
  def performance_at(production, time_string, date: show_date)
    FactoryBot.create(:performance, production: production,
                                    performance_date: date,
                                    performance_time: Time.parse("#{date} #{time_string}"))
  end

  def shadow_for(resource, production)
    TicketClass.find_by(production_id: production.id, resourced_ticket_class_id: resource.id)
  end

  # The shadow saves fire TicketClass#sync_allocations_async, which enqueues one
  # SyncTicketClassAllocationsJob per class. Drain those inline so allocation
  # side effects are observable here.
  def run_allocation_jobs_for(resource)
    TicketClass.where(resourced_ticket_class_id: resource.id).each do |tc|
      SyncTicketClassAllocationsJob.perform(tc.id, tc.production_id)
    end
  end

  describe 'shadow class creation' do
    it 'creates one shadow class per production across all of the resource venues' do
      prod_a = production_in(venue_a)
      prod_b = production_in(venue_b)
      unrelated = production_in(other_venue)
      performance_at(prod_a, '19:00')
      performance_at(prod_b, '19:00')
      performance_at(unrelated, '19:00')

      resource = FactoryBot.create(:resourced_ticket_class, venues: [venue_a, venue_b])
      described_class.perform(resource.id)

      expect(shadow_for(resource, prod_a)).to be_present
      expect(shadow_for(resource, prod_b)).to be_present
      expect(shadow_for(resource, unrelated)).to be_nil
    end

    it 'copies the resource attributes onto the shadow class' do
      prod = production_in(venue_a)
      performance_at(prod, '19:00')
      resource = FactoryBot.create(:resourced_ticket_class, venues: [venue_a],
                                                            ticket_price: 3, holds_seats: false,
                                                            web_visible: true, auto_attach: true)
      described_class.perform(resource.id)

      shadow = shadow_for(resource, prod)
      expect(shadow.class_code).to eq(resource.class_code)
      expect(shadow.class_name).to eq(resource.class_name)
      expect(shadow.ticket_price).to eq(3)
      expect(shadow.holds_seats).to be false
      expect(shadow.web_visible).to be true
      expect(shadow).to be_resourced
      # The pool attributes never leak onto the ticket class.
      expect(shadow).not_to respond_to(:quantity)
    end

    it 'is idempotent and re-syncs changed attributes onto existing shadow rows' do
      prod = production_in(venue_a)
      performance_at(prod, '19:00')
      resource = FactoryBot.create(:resourced_ticket_class, venues: [venue_a], web_visible: true)
      described_class.perform(resource.id)
      original_id = shadow_for(resource, prod).id

      resource.update!(class_name: 'Renamed Tablet', web_visible: false)
      described_class.perform(resource.id)

      shadow = shadow_for(resource, prod)
      expect(shadow.id).to eq(original_id)
      expect(shadow.class_name).to eq('Renamed Tablet')
      expect(shadow.web_visible).to be false
      expect(TicketClass.where(resourced_ticket_class_id: resource.id).count).to eq(1)
    end

    it 'skips closed productions but covers productions with no performances yet' do
      closed = production_in(venue_a)
      performance_at(closed, '19:00', date: Date.current - 30.days)
      empty = production_in(venue_a)

      resource = FactoryBot.create(:resourced_ticket_class, venues: [venue_a])
      described_class.perform(resource.id)

      expect(shadow_for(resource, closed)).to be_nil
      expect(shadow_for(resource, empty)).to be_present
    end
  end

  describe 'allocations' do
    it 'yields available allocations for future sellable performances via the chained job' do
      prod = production_in(venue_a)
      future = performance_at(prod, '19:00')
      resource = FactoryBot.create(:resourced_ticket_class, venues: [venue_a], auto_attach: true)

      described_class.perform(resource.id)
      run_allocation_jobs_for(resource)

      shadow = shadow_for(resource, prod)
      tca = TicketClassAllocation.find_by(performance_id: future.id, ticket_class_id: shadow.id)
      expect(tca).to be_present
      expect(tca.available).to be true
    end

    it 'leaves allocations unavailable when the resource does not auto_attach' do
      prod = production_in(venue_a)
      future = performance_at(prod, '19:00')
      resource = FactoryBot.create(:resourced_ticket_class, venues: [venue_a], auto_attach: false)

      described_class.perform(resource.id)
      run_allocation_jobs_for(resource)

      shadow = shadow_for(resource, prod)
      tca = TicketClassAllocation.find_by(performance_id: future.id, ticket_class_id: shadow.id)
      expect(tca).to be_present
      expect(tca.available).to be false
    end
  end

  describe 'decommission on venue removal' do
    it 'withdraws the shadow class from sale and switches off future allocations' do
      prod = production_in(venue_b)
      future = performance_at(prod, '19:00')
      past = performance_at(prod, '19:00', date: Date.current - 5.days)
      resource = FactoryBot.create(:resourced_ticket_class, venues: [venue_a, venue_b])
      described_class.perform(resource.id)
      run_allocation_jobs_for(resource)

      shadow = shadow_for(resource, prod)
      past_tca = TicketClassAllocation.find_or_create_by!(performance: past, ticket_class: shadow)
      past_tca.update!(available: true)

      resource.update!(venue_ids: [venue_a.id])
      described_class.perform(resource.id)

      shadow.reload
      expect(shadow.auto_attach).to be false
      expect(shadow.web_visible).to be false
      # History is preserved: the row survives and past allocations are untouched.
      expect(TicketClass.find_by(id: shadow.id)).to be_present
      expect(past_tca.reload.available).to be true

      future_tca = TicketClassAllocation.find_by(performance_id: future.id, ticket_class_id: shadow.id)
      expect(future_tca.available).to be false
    end
  end

  describe 'class_code collisions' do
    it 'logs the collision and still processes the other productions' do
      colliding_prod = production_in(venue_a)
      clean_prod = production_in(venue_a)
      performance_at(colliding_prod, '19:00')
      performance_at(clean_prod, '19:00')

      resource = FactoryBot.create(:resourced_ticket_class, venues: [venue_a], class_code: 'ASSIST')
      # A manual class already owns ASSIST on this production.
      TicketClass.create!(production: colliding_prod, class_code: 'ASSIST', class_name: 'Legacy assist',
                          ticket_type: 'Fixed', ticket_price: 0, ticketing_fee: 0)

      expect(Rails.logger).to receive(:warn).with(/could not sync 'ASSIST'/).at_least(:once)
      expect { described_class.perform(resource.id) }.not_to raise_error

      expect(shadow_for(resource, colliding_prod)).to be_nil
      expect(shadow_for(resource, clean_prod)).to be_present
      # The legacy class is never adopted.
      legacy = TicketClass.find_by(production_id: colliding_prod.id, class_code: 'ASSIST')
      expect(legacy.resourced_ticket_class_id).to be_nil
      expect(legacy.class_name).to eq('Legacy assist')
    end
  end

  it 'does nothing when the resource has been deleted' do
    expect { described_class.perform(-1) }.not_to raise_error
  end
end
