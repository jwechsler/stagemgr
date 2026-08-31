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

    it 'does not propagate when the source allocation is left unavailable' do
      [edited, later].each(&:save!)
      tca = allocation_for(edited)

      edited.update!(ticket_class_allocations_attributes: [{ id: tca.id, available: '0',
                                                             propagate_available: '1' }])

      expect(allocation_for(later).reload.available).to be_falsy
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

    it 'creates a missing allocation on a later performance rather than skipping it' do
      [edited, later].each(&:save!)
      allocation_for(later).destroy!
      later.ticket_class_allocations.reload

      enable_and_propagate!(edited)

      expect(allocation_for(later)).to be_present
      expect(allocation_for(later).available).to be true
    end
  end
end
