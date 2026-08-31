require 'rails_helper'

# A ResourcedTicketClass is a global ticket class backed by a limited pool of
# physical devices shared across venues. The interesting logic is the occupancy
# window and #remaining_for, which resolves pool usage across every overlapping
# performance in the resource's venues -- so these examples lean on the real
# MySQL TIMESTAMP/INTERVAL predicate rather than stubbing it.
RSpec.describe ResourcedTicketClass do
  let(:venue_a) { FactoryBot.create(:venue) }
  let(:venue_b) { FactoryBot.create(:venue) }
  let(:theater) { FactoryBot.create(:theater) }

  # 15-minute-aligned dates/times throughout: Performance#clean_values rounds
  # performance_time down to the nearest 15 minutes.
  let(:show_date) { Date.current + 30.days }

  def resource(quantity: 2, changeover: 30, venues: [venue_a, venue_b], **attrs)
    FactoryBot.create(:resourced_ticket_class,
                      quantity: quantity, changeover_minutes: changeover,
                      venues: venues, **attrs)
  end

  def production_in(venue, running_time: 120, **attrs)
    FactoryBot.create(:production, venue: venue, theater: theater,
                                   running_time: running_time, **attrs)
  end

  # performance_time is a plain MySQL TIME column and is NOT time-zone aware:
  # whatever is assigned gets converted to the SYSTEM zone before it is written,
  # while Performance#to_time_with_zone reads the stored wall clock back in the
  # APPLICATION zone. Passing a bare Time (system zone, like the rest of the
  # suite) is what makes the stored wall clock match the hour asked for here.
  # Do not use Time.zone.parse -- on a box whose system zone differs from
  # Rails.application.config.time_zone the hour shifts.
  def performance_at(production, time_string, date: show_date)
    FactoryBot.create(:performance, production: production,
                                    performance_date: date,
                                    performance_time: Time.parse("#{date} #{time_string}"))
  end

  # Attach the resource's shadow class to a production without going through the
  # background job (that job has its own spec). Idempotent: when the resource
  # already existed at production-create time, Production's after_create hook
  # will have made the row already.
  def shadow_class_for(res, production)
    tc = TicketClass.find_or_initialize_by(production_id: production.id,
                                           resourced_ticket_class_id: res.id)
    tc.synced_from_resource = true
    tc.attributes = res.shadow_attributes
    tc.save!
    tc
  end

  def allocate(shadow, performance)
    tca = TicketClassAllocation.find_or_create_by!(performance: performance, ticket_class: shadow)
    tca.update!(available: true)
    performance.ticket_class_allocations.reload
    tca
  end

  def sell(shadow, performance, count, status: Order::PROCESSED)
    allocate(shadow, performance)
    order = TicketOrder.new(status: status, performance: performance,
                            address: FactoryBot.create(:address),
                            payment_type: FactoryBot.create(:cash_payment_type))
    order.ticket_line_items << TicketLineItem.new(ticket_class: shadow, ticket_count: count)
    order.save!
    order
  end

  describe 'validations' do
    it 'is valid with the factory defaults' do
      expect(resource).to be_valid
    end

    it 'upcases class_code and enforces global uniqueness' do
      resource(venues: [venue_a]).update!(class_code: 'tablet')
      dup = FactoryBot.build(:resourced_ticket_class, class_code: 'TaBlEt', venues: [venue_a])

      expect(dup).not_to be_valid
      expect(dup.errors[:class_code]).to be_present
      expect(ResourcedTicketClass.find_by(class_code: 'TABLET')).to be_present
    end

    it 'requires class_code, class_name, ticket_price and ticketing_fee' do
      rtc = ResourcedTicketClass.new(quantity: 1, changeover_minutes: 0,
                                     ticket_type: 'Fixed', ticket_price: nil,
                                     ticketing_fee: nil)
      rtc.valid?

      expect(rtc.errors[:class_code]).to be_present
      expect(rtc.errors[:class_name]).to be_present
      expect(rtc.errors[:ticket_price]).to be_present
      expect(rtc.errors[:ticketing_fee]).to be_present
    end

    it 'rejects a ticket type outside TicketClass::TICKET_TYPES' do
      rtc = FactoryBot.build(:resourced_ticket_class, ticket_type: 'Sliding', venues: [venue_a])

      expect(rtc).not_to be_valid
      expect(rtc.errors[:ticket_type]).to be_present
    end

    it 'defaults zone_id to the wildcard and upcases a supplied zone' do
      expect(resource(venues: [venue_a]).zone_id).to eq(ZoneMatchable::WILDCARD)
      expect(resource(venues: [venue_a], zone_id: ' b1 ').zone_id).to eq('B1')
    end

    it 'rejects a zone outside the class zone format' do
      rtc = FactoryBot.build(:resourced_ticket_class, zone_id: 'ABC', venues: [venue_a])

      expect(rtc).not_to be_valid
      expect(rtc.errors[:zone_id]).to be_present
    end

    it 'requires a positive integer quantity' do
      expect(FactoryBot.build(:resourced_ticket_class, quantity: 0, venues: [venue_a])).not_to be_valid
      expect(FactoryBot.build(:resourced_ticket_class, quantity: -1, venues: [venue_a])).not_to be_valid
      expect(FactoryBot.build(:resourced_ticket_class, quantity: 1, venues: [venue_a])).to be_valid
    end

    it 'requires changeover_minutes between 0 and the documented 12 hour bound' do
      expect(FactoryBot.build(:resourced_ticket_class, changeover_minutes: 0, venues: [venue_a])).to be_valid
      expect(FactoryBot.build(:resourced_ticket_class, changeover_minutes: -1, venues: [venue_a])).not_to be_valid
      expect(FactoryBot.build(:resourced_ticket_class,
                              changeover_minutes: described_class::MAX_CHANGEOVER_MINUTES,
                              venues: [venue_a])).not_to be_valid
    end

    it 'requires at least one venue' do
      rtc = FactoryBot.build(:resourced_ticket_class, venues: [])

      expect(rtc).not_to be_valid
      expect(rtc.errors[:venues]).to be_present
    end

    it 'refuses a price change once a shadow class has sales' do
      res = resource(venues: [venue_a], ticket_price: 5)
      prod = production_in(venue_a)
      shadow = shadow_class_for(res, prod)
      perf = performance_at(prod, '19:00')
      sell(shadow, perf, 1)

      res.ticket_price = 9
      expect(res).not_to be_valid
      expect(res.errors[:base].join).to match(/Cannot change ticket price/)
    end

    it 'allows a price change while no shadow class has sales' do
      res = resource(venues: [venue_a], ticket_price: 5)
      shadow_class_for(res, production_in(venue_a))

      expect(res.update(ticket_price: 9)).to be true
    end
  end

  describe '#shadow_attributes' do
    it 'omits identity, timestamps and the pool-only attributes' do
      attrs = resource(venues: [venue_a]).shadow_attributes

      expect(attrs.keys).not_to include('id', 'quantity', 'changeover_minutes',
                                        'created_at', 'updated_at')
      expect(attrs['class_code']).to be_present
      expect(attrs['zone_id']).to eq(ZoneMatchable::WILDCARD)
    end

    it 'assigns cleanly onto a TicketClass' do
      res = resource(venues: [venue_a])
      shadow = shadow_class_for(res, production_in(venue_a))

      expect(shadow.class_code).to eq(res.class_code)
      expect(shadow.ticket_price).to eq(res.ticket_price)
      expect(shadow.holds_seats).to be false
      expect(shadow).to be_resourced
    end
  end

  describe '#occupancy_window_for' do
    it 'brackets curtain through running time with the changeover on both ends' do
      res = resource(changeover: 30, venues: [venue_a])
      perf = performance_at(production_in(venue_a, running_time: 120), '14:00')

      window_start, window_end = res.occupancy_window_for(perf)

      expect(window_start).to eq(Time.zone.parse("#{show_date} 13:30"))
      expect(window_end).to eq(Time.zone.parse("#{show_date} 16:30"))
    end

    it 'falls back to the server.yml runtime when running_time is nil' do
      allow(Rails.configuration.x.server_config).to receive(:[]).and_call_original
      allow(Rails.configuration.x.server_config).to receive(:[])
        .with('resourced_default_runtime_minutes').and_return(240)
      res = resource(changeover: 15, venues: [venue_a])
      prod = production_in(venue_a, running_time: 120)
      perf = performance_at(prod, '14:00')
      prod.update_column(:running_time, nil)
      perf.production.reload

      _window_start, window_end = res.occupancy_window_for(perf)

      expect(res.default_runtime_minutes).to eq(240)
      # 14:00 + 240 + 15
      expect(window_end).to eq(Time.zone.parse("#{show_date} 18:15"))
    end

    it 'falls back to the hard-coded default when the config key is missing' do
      allow(Rails.configuration.x.server_config).to receive(:[]).and_call_original
      allow(Rails.configuration.x.server_config).to receive(:[])
        .with('resourced_default_runtime_minutes').and_return(nil)

      expect(resource(venues: [venue_a]).default_runtime_minutes)
        .to eq(described_class::FALLBACK_RUNTIME_MINUTES)
    end
  end

  describe '#remaining_for' do
    let(:res) { resource(quantity: 2, changeover: 30) }
    let(:prod_a) { production_in(venue_a, running_time: 120) }
    let(:prod_b) { production_in(venue_b, running_time: 120) }
    let(:shadow_a) { shadow_class_for(res, prod_a) }
    let(:shadow_b) { shadow_class_for(res, prod_b) }

    it 'returns the full quantity when nothing has been sold' do
      expect(res.remaining_for(performance_at(prod_a, '14:00'))).to eq(2)
    end

    it 'counts an overlapping performance in a DIFFERENT venue' do
      # A: 14:00 + 120 -> busy 13:30-16:30. B: 15:00 -> busy 14:30-17:30.
      sold_perf = performance_at(prod_a, '14:00')
      sell(shadow_a, sold_perf, 2)

      target = performance_at(prod_b, '15:00')
      expect(res.remaining_for(target)).to eq(0)
      expect(shadow_b.resource_available?(target)).to be false
    end

    it 'ignores a performance whose window does not overlap' do
      sell(shadow_a, performance_at(prod_a, '14:00'), 2)

      # 20:00 -> busy 19:30-22:30, well clear of 13:30-16:30.
      expect(res.remaining_for(performance_at(prod_b, '20:00'))).to eq(2)
    end

    it 'treats exactly-abutting windows as compatible' do
      # A: 14:00 curtain, 120 min runtime, 30 min changeover -> busy until 16:30.
      sell(shadow_a, performance_at(prod_a, '14:00'), 2)

      # B: 17:00 curtain, 30 min changeover -> starts occupying at 16:30.
      expect(res.remaining_for(performance_at(prod_b, '17:00'))).to eq(2)
    end

    it 'counts a window that overlaps by a single 15 minute block' do
      sell(shadow_a, performance_at(prod_a, '14:00'), 1)

      # B: 16:45 curtain -> occupies from 16:15, one block inside 13:30-16:30.
      expect(res.remaining_for(performance_at(prod_b, '16:45'))).to eq(1)
    end

    it 'counts overlap across a midnight boundary' do
      late = performance_at(prod_a, '23:00') # busy 22:30 - 01:30 next day
      sell(shadow_a, late, 2)

      early = performance_at(prod_b, '00:30', date: show_date + 1.day) # busy 00:00 - 03:00
      expect(res.remaining_for(early)).to eq(0)
    end

    it 'excludes performances in a venue outside the resource scope' do
      venue_c = FactoryBot.create(:venue)
      out_of_scope = production_in(venue_c, running_time: 120)
      out_shadow = shadow_class_for(res, out_of_scope)
      sell(out_shadow, performance_at(out_of_scope, '14:00'), 2)

      expect(res.remaining_for(performance_at(prod_a, '14:00'))).to eq(2)
    end

    it 'counts the target performance own other orders' do
      target = performance_at(prod_a, '14:00')
      sell(shadow_a, target, 1)

      expect(res.remaining_for(target)).to eq(1)
    end

    describe 'order status filtering' do
      it 'counts Hold and Exchanging but not Refunded, Releasing, Canceled or Exchanged' do
        perf = performance_at(prod_a, '14:00')

        sell(shadow_a, perf, 1, status: Order::HOLD)
        expect(res.remaining_for(perf)).to eq(1)

        sell(shadow_a, perf, 5, status: Order::REFUNDED)
        sell(shadow_a, perf, 5, status: Order::RELEASING)
        sell(shadow_a, perf, 5, status: Order::CANCELED)
        sell(shadow_a, perf, 5, status: Order::EXCHANGED)
        expect(res.remaining_for(perf)).to eq(1)

        sell(shadow_a, perf, 1, status: Order::EXCHANGING)
        expect(res.remaining_for(perf)).to eq(0)
      end
    end

    it 'nets refund line items out of the sum' do
      perf = performance_at(prod_a, '14:00')
      order = sell(shadow_a, perf, 2)
      expect(res.remaining_for(perf)).to eq(0)

      TicketLineItem.create!(order_id: order.id, ticket_class_id: shadow_a.id, ticket_count: -1)
      expect(res.remaining_for(perf)).to eq(1)
    end

    it 'ignores the excluded order own devices' do
      perf = performance_at(prod_a, '14:00')
      order = sell(shadow_a, perf, 2)

      expect(res.remaining_for(perf)).to eq(0)
      expect(res.remaining_for(perf, exclude_order: order)).to eq(2)
    end

    it 'returns the full quantity when the resource has no shadow classes yet' do
      bare = resource(quantity: 3, venues: [venue_a])

      expect(bare.remaining_for(performance_at(prod_a, '14:00'))).to eq(3)
    end
  end

  describe 'sync tracking' do
    it 'marks a sync pending on create and settles it on completion' do
      res = FactoryBot.create(:resourced_ticket_class)
      expect(res).to be_syncing

      res.mark_sync_completed!
      expect(res).not_to be_syncing
    end

    it 'stacks pending syncs across successive saves' do
      res = FactoryBot.create(:resourced_ticket_class)
      res.update!(class_name: 'Renamed')

      expect(res.reload.sync_pending_count).to eq(2)
      res.mark_sync_completed!
      expect(res).to be_syncing
    end

    it 'clamps the counter at zero on surplus completions' do
      res = FactoryBot.create(:resourced_ticket_class)
      res.mark_sync_completed!
      res.mark_sync_completed!

      expect(res.reload.sync_pending_count).to eq(0)
    end
  end

  describe 'deletion' do
    it 'destroys shadow rows and their allocations when nothing has sold' do
      res = resource(venues: [venue_a])
      prod = production_in(venue_a)
      shadow = shadow_class_for(res, prod)
      perf = performance_at(prod, '19:00')
      TicketClassAllocation.find_or_create_by!(performance: perf, ticket_class: shadow)

      expect(res.destroy).to be_truthy
      expect(TicketClass.where(id: shadow.id)).to be_empty
      expect(TicketClassAllocation.where(ticket_class_id: shadow.id)).to be_empty
    end

    it 'refuses to delete once a shadow row has sales, and decommissions instead' do
      res = resource(venues: [venue_a])
      prod = production_in(venue_a)
      shadow = shadow_class_for(res, prod)
      perf = performance_at(prod, '19:00')
      tca = TicketClassAllocation.find_or_create_by!(performance: perf, ticket_class: shadow)
      tca.update!(available: true)
      sell(shadow, perf, 1)

      expect(res.destroy).to be false
      expect(res.errors[:base].join).to match(/already sold this equipment/)
      expect(described_class.find_by(id: res.id)).to be_present

      shadow.reload
      expect(shadow.auto_attach).to be false
      expect(shadow.web_visible).to be false
      expect(tca.reload.available).to be false
    end
  end
end
