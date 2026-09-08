require 'rails_helper'

# The allocation grid's "propagate availability" toggle: a form-only flag on
# TicketClassAllocation that, when the performance SAVES, also enables the same
# ticket class on every later performance of the run -- anchored to the edited
# performance's own date/time, not the current date.
RSpec.describe 'allocation availability propagation' do
  let(:venue)   { FactoryBot.create(:venue) }
  let(:theater) { FactoryBot.create(:theater) }
  let(:production) { FactoryBot.create(:production, venue: venue, theater: theater, running_time: 120) }
  let(:resource) { FactoryBot.create(:resourced_ticket_class, venues: [venue]) }

  let(:shadow) do
    tc = TicketClass.find_or_initialize_by(production_id: production.id,
                                           resourced_ticket_class_id: resource.id)
    tc.synced_from_resource = true
    tc.attributes = resource.shadow_attributes
    tc.save!
    # The shared production object cached ticket_classes before the shadow
    # existed; Performance#populate_ticket_class_allocations reads through it.
    production.ticket_classes.reload
    tc
  end

  # performance_time is a plain TIME column; a bare (system zone) Time stores
  # the hour asked for. Minutes round down to 15-minute blocks.
  def performance_at(date, time_string)
    FactoryBot.create(:performance, production: production,
                                    performance_date: date,
                                    performance_time: Time.parse("#{date} #{time_string}"))
  end

  def allocation_for(performance)
    TicketClassAllocation.find_by(performance_id: performance.id, ticket_class_id: shadow.id)
  end

  def enable_and_propagate!(performance)
    performance.update!(
      ticket_class_allocations_attributes: [{ id: allocation_for(performance).id,
                                              available: '1', propagate_available: '1' }]
    )
  end

  describe 'saving a mid-run performance with the flag set' do
    let(:run_start)  { Date.current + 10.days }
    let!(:earlier)   { performance_at(run_start, '19:00') }
    let!(:edited)    { performance_at(run_start + 7.days, '19:00') }
    let!(:same_slot) { performance_at(run_start + 7.days, '21:00') }
    let!(:later)     { performance_at(run_start + 14.days, '19:00') }

    before { shadow } # materialize + allocations via populate on create? no -- see below

    it 'enables the class from this performance onward and leaves earlier ones alone' do
      # Allocations exist for performances created after the shadow class; the
      # earlier-created performances need theirs populated (a save does it).
      [earlier, edited, same_slot, later].each(&:save!)

      enable_and_propagate!(edited)

      expect(allocation_for(edited).reload.available).to be true
      expect(allocation_for(same_slot).reload.available).to be true
      expect(allocation_for(later).reload.available).to be true
      expect(allocation_for(earlier).reload.available).to be_falsy
    end

    it 'does not propagate without the flag' do
      [earlier, edited, later].each(&:save!)
      tca = allocation_for(edited)

      edited.update!(ticket_class_allocations_attributes: [{ id: tca.id, available: '1' }])

      expect(allocation_for(later).reload.available).to be_falsy
    end

    it 'propagates a deactivation: an unavailable row switches the class off on later performances' do
      [earlier, edited, later].each(&:save!)
      [earlier, edited, later].each { |perf| allocation_for(perf).update!(available: true) }
      tca = allocation_for(edited)

      edited.update!(ticket_class_allocations_attributes: [{ id: tca.id, available: '0',
                                                             propagate_available: '1' }])

      expect(allocation_for(edited).reload.available).to be false
      expect(allocation_for(later).reload.available).to be false
      expect(allocation_for(earlier).reload.available).to be true
    end

    it 'does not propagate when the performance fails to save' do
      [edited, later].each(&:save!)
      tca = allocation_for(edited)

      # A performance_code that does not start with the production's code fails
      # validation (a nil date would just be backfilled by clean_values).
      expect(
        edited.update(performance_code: 'ZZZBAD',
                      ticket_class_allocations_attributes: [{ id: tca.id, available: '1',
                                                              propagate_available: '1' }])
      ).to be false

      expect(allocation_for(later).reload.available).to be_falsy
    end

    it 'copies the limit and trigger settings along with the availability' do
      [edited, same_slot, later].each(&:save!)
      tca = allocation_for(edited)
      # Give the target an existing (stale) config to prove it gets overwritten.
      allocation_for(later).update!(available: true, ticket_limit: 99)

      edited.update!(
        ticket_class_allocations_attributes: [{ id: tca.id, available: '1', propagate_available: '1',
                                                ticket_limit: 10, shiftable: '1',
                                                shift_to_code: shadow.class_code,
                                                shift_when_capacity_over: 80,
                                                shift_days_before_performance: 3 }]
      )

      [same_slot, later].each do |perf|
        target = allocation_for(perf).reload
        expect(target.available).to be true
        expect(target.ticket_limit).to eq(10)
        expect(target.shiftable).to be true
        expect(target.shift_to_code).to eq(shadow.class_code)
        expect(target.shift_when_capacity_over).to eq(80)
        expect(target.shift_days_before_performance).to eq(3)
      end
      expect(allocation_for(earlier)).to be_nil # never saved -> never populated
    end

    it 'propagates plain (non-resourced) ticket classes too' do
      plain = TicketClass.create!(production: production, class_code: 'PLAIN',
                                  class_name: 'Plain class', ticket_type: 'Fixed',
                                  ticket_price: 10, ticketing_fee: 1, auto_attach: false)
      production.ticket_classes.reload
      [edited, later].each(&:save!)
      tca = TicketClassAllocation.find_by(performance_id: edited.id, ticket_class_id: plain.id)

      edited.update!(ticket_class_allocations_attributes: [{ id: tca.id, available: '1',
                                                             propagate_available: '1' }])

      later_tca = TicketClassAllocation.find_by(performance_id: later.id, ticket_class_id: plain.id)
      expect(later_tca.available).to be true
    end

    it 'creates a missing allocation on a later performance rather than skipping it' do
      [edited, later].each(&:save!)
      allocation_for(later).destroy!
      later.ticket_class_allocations.reload

      enable_and_propagate!(edited)

      expect(allocation_for(later)).to be_present
      expect(allocation_for(later).available).to be true
    end
  end

  # Reset and replay. `available` records only whether a tier is on sale, not
  # why, so a later performance whose dynamic pricing ladder already advanced
  # (LOW off, MID on) would otherwise end up with the propagated LOW *and* MID
  # on sale. Propagation walks the later performance's existing ladder from the
  # row and switches it off, lands the new row, then re-runs that performance's
  # triggers against its own sales.
  describe 'dynamic pricing ladders on later performances' do
    let(:production) { FactoryBot.create(:production, venue: venue, theater: theater, capacity: 10) }
    let(:run_start)  { Date.current + 10.days }
    let!(:edited)    { performance_at(run_start, '19:00') }
    let!(:later)     { performance_at(run_start + 7.days, '19:00') }

    # Plain, manually managed, seat-holding classes; codes unique to this spec
    # because the :ticket_class factory's find_or_create_by ignores production.
    let!(:low)  { ladder_class('LADLOW', 10) }
    let!(:mid)  { ladder_class('LADMID', 20) }
    let!(:high) { ladder_class('LADHIGH', 30) }

    def ladder_class(code, price)
      FactoryBot.create(:ticket_class, production: production, class_code: code, class_name: code,
                                       ticket_price: price, auto_attach: false, web_visible: true, holds_seats: true)
    end

    def row(performance, ticket_class)
      TicketClassAllocation.find_by!(performance_id: performance.id, ticket_class_id: ticket_class.id)
    end

    def configure(performance, ticket_class, attrs)
      row(performance, ticket_class).update!(attrs)
    end

    # A fresh Performance so the factory sees the rows `configure` just wrote
    # (it picks the first available allocation's class).
    def sell_seats(performance, count)
      count.times do
        FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_credit_card,
                          performance: Performance.find(performance.id))
      end
    end

    # Submit the edited performance's LOW row through the form, flag armed.
    def propagate_low!(attrs)
      edited.update!(ticket_class_allocations_attributes: [{ id: row(edited, low).id,
                                                             propagate_available: '1' }.merge(attrs)])
    end

    def availability(performance)
      [low, mid, high].map { |tc| row(performance, tc).reload.available? }
    end

    before do
      production.ticket_classes.reload
      [edited, later].each(&:save!) # populate allocation rows for the new classes
    end

    # `later` has already shifted LOW -> MID under the old 20% rule.
    def shift_later_low_to_mid!(percent_sold: 30)
      configure(later, low, available: false, shiftable: true, shift_to_code: mid.class_code,
                            shift_when_capacity_over: 20)
      configure(later, mid, available: true)
      sell_seats(later, percent_sold / 10)
    end

    it 'restores the head tier and switches the shifted tier off when the new threshold is not met' do
      shift_later_low_to_mid!(percent_sold: 30)

      propagate_low!(available: '1', shiftable: '1', shift_to_code: mid.class_code, shift_when_capacity_over: 40)

      expect(availability(later)).to eq([true, false, false])
      expect(row(later, low).shift_when_capacity_over).to eq(40)
    end

    it 'replays the triggers so a performance past the new threshold ends up on the shifted tier' do
      shift_later_low_to_mid!(percent_sold: 50)

      propagate_low!(available: '1', shiftable: '1', shift_to_code: mid.class_code, shift_when_capacity_over: 40)

      expect(availability(later)).to eq([false, true, false])
    end

    it 'switches off the OLD target when the row is retargeted' do
      shift_later_low_to_mid!(percent_sold: 30)

      propagate_low!(available: '1', shiftable: '1', shift_to_code: high.class_code, shift_when_capacity_over: 40)

      expect(availability(later)).to eq([true, false, false])
    end

    it 'resets a fully advanced cascade' do
      configure(later, low,  available: false, shiftable: true, shift_to_code: mid.class_code, shift_when_capacity_over: 10)
      configure(later, mid,  available: false, shiftable: true, shift_to_code: high.class_code, shift_when_capacity_over: 20)
      configure(later, high, available: true)
      sell_seats(later, 3)

      propagate_low!(available: '1', shiftable: '1', shift_to_code: mid.class_code, shift_when_capacity_over: 40)

      expect(availability(later)).to eq([true, false, false])
    end

    it 'propagating the head OFF also switches off the tier it had shifted to' do
      shift_later_low_to_mid!(percent_sold: 30)

      propagate_low!(available: '0', shiftable: '1', shift_to_code: mid.class_code, shift_when_capacity_over: 20)

      expect(availability(later)).to eq([false, false, false])
    end

    it 'terminates on a mis-configured cycle' do
      shift_later_low_to_mid!(percent_sold: 30)
      configure(later, mid, shiftable: true, shift_to_code: low.class_code, shift_when_capacity_over: 90)

      expect do
        propagate_low!(available: '1', shiftable: '1', shift_to_code: mid.class_code, shift_when_capacity_over: 40)
      end.not_to raise_error
      expect(availability(later)).to eq([true, false, false])
    end

    it 'leaves a later performance alone when the row is not propagated' do
      shift_later_low_to_mid!(percent_sold: 30)

      edited.update!(ticket_class_allocations_attributes: [{ id: row(edited, low).id, available: '1',
                                                             shiftable: '1', shift_to_code: mid.class_code,
                                                             shift_when_capacity_over: 40 }])

      expect(availability(later)).to eq([false, true, false])
    end

    it 'lands every armed row before replaying, so rows armed together cannot undo each other' do
      configure(later, low, available: true)
      sell_seats(later, 3)
      configure(later, low, available: false)

      # LOW on (-> MID at 20%) and MID off, both armed. Per performance: land
      # both, then scan once. A per-row reset/land/scan would promote LOW -> MID
      # and then land MID off, leaving nothing on sale.
      edited.update!(ticket_class_allocations_attributes: [
                       { id: row(edited, low).id, available: '1', propagate_available: '1', shiftable: '1',
                         shift_to_code: mid.class_code, shift_when_capacity_over: 20 },
                       { id: row(edited, mid).id, available: '0', propagate_available: '1' }
                     ])

      expect(availability(later)).to eq([false, true, false])
    end

    it 'never switches off an auto-attach tier when resetting a ladder' do
      auto = FactoryBot.create(:ticket_class, production: production, class_code: 'LADAUTO', class_name: 'auto',
                                              ticket_price: 40, auto_attach: true, web_visible: true, holds_seats: true)
      production.ticket_classes.reload
      [edited, later].each(&:save!)
      configure(later, low, available: false, shiftable: true, shift_to_code: auto.class_code,
                            shift_when_capacity_over: 20)

      propagate_low!(available: '1', shiftable: '1', shift_to_code: auto.class_code, shift_when_capacity_over: 40)

      expect(row(later, low).reload.available?).to be true
      expect(row(later, auto).reload.available?).to be true
    end

    it 'reports a later row that cannot be saved instead of failing silently' do
      shift_later_low_to_mid!(percent_sold: 30)
      # An invalid row on the ladder (shiftable with no target), bypassing validation.
      row(later, mid).update_columns(shiftable: true, shift_to_code: nil)

      result = edited.update(ticket_class_allocations_attributes: [{ id: row(edited, low).id, available: '1',
                                                                     propagate_available: '1', shiftable: '1',
                                                                     shift_to_code: mid.class_code,
                                                                     shift_when_capacity_over: 40 }])

      expect(result).to be false
      expect(edited.errors[:base].first).to include(later.performance_code)
      expect(row(later, mid).reload.available?).to be true # rolled back
    end

    it 'does not run the scan when a save merely populated a new allocation row' do
      # LOW on the edited performance is shiftable on a met date trigger, but a
      # new class being populated is not a grid edit.
      configure(edited, low, available: true, shiftable: true, shift_to_code: mid.class_code,
                             shift_days_before_performance: 1000)
      FactoryBot.create(:ticket_class, production: production, class_code: 'LADNEW', class_name: 'new',
                                       ticket_price: 5, auto_attach: false)
      production.ticket_classes.reload

      edited.reload.save!

      expect(availability(edited)).to eq([true, false, false])
    end

    # The edited performance gets the same treatment when a ladder head is
    # re-armed in the form, except that boxes staff touched in the same save win.
    describe 'on the edited performance itself' do
      # `edited` has already shifted LOW -> MID under an old 15% rule and sits
      # at 30% sold.
      before do
        configure(edited, low, available: false, shiftable: true, shift_to_code: mid.class_code,
                               shift_when_capacity_over: 15)
        configure(edited, mid, available: true)
        sell_seats(edited, 3)
      end

      def rearm_low!(attrs, extra_rows = [])
        edited.reload.update!(ticket_class_allocations_attributes: [{ id: row(edited, low).id }.merge(attrs)] + extra_rows)
      end

      it 're-checking the head with a threshold not yet met switches the shifted tier off' do
        rearm_low!(available: '1', shift_when_capacity_over: 35)

        expect(availability(edited)).to eq([true, false, false])
      end

      it 're-checking the head with a threshold already met replays straight back to the shifted tier' do
        rearm_low!(available: '1', shift_when_capacity_over: 20)

        expect(availability(edited)).to eq([false, true, false])
      end

      it 'retargeting the head switches off the OLD target too' do
        rearm_low!(available: '1', shift_to_code: high.class_code, shift_when_capacity_over: 35)

        expect(availability(edited)).to eq([true, false, false])
      end

      it 'leaves a tier alone that staff explicitly checked in the same save' do
        configure(edited, mid, available: false)

        rearm_low!({ available: '1', shift_when_capacity_over: 35 }, [{ id: row(edited, mid).id, available: '1' }])

        expect(availability(edited)).to eq([true, true, false])
      end

      it 'arming the toggle on an otherwise unchanged head resets its ladder here as well as forward' do
        configure(edited, low, available: true, shift_when_capacity_over: 35)

        edited.reload.update!(ticket_class_allocations_attributes: [{ id: row(edited, low).id,
                                                                      propagate_available: '1' }])

        expect(availability(edited)).to eq([true, false, false])
        expect(row(later, low).reload.shift_when_capacity_over).to eq(35)
      end

      it 'does not reset a ladder whose head was left unavailable' do
        rearm_low!(shift_when_capacity_over: 35)

        expect(availability(edited)).to eq([false, true, false])
      end

      it 'does not reset anything when only an unrelated row changed' do
        edited.reload.update!(ticket_class_allocations_attributes: [{ id: row(edited, high).id, ticket_limit: 5 }])

        expect(availability(edited)).to eq([false, true, false])
      end
    end

    it 'runs the triggers on the edited performance itself right after it saves' do
      edited.update!(ticket_class_allocations_attributes: [{ id: row(edited, low).id, available: '1',
                                                             shiftable: '1', shift_to_code: mid.class_code,
                                                             shift_days_before_performance: 1000 }])

      expect(availability(edited)).to eq([false, true, false])
    end
  end
end
