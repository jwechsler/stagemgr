require 'rails_helper'

# Characterization spec for TicketOrder#wheelchair_requested?. A rubocop autocorrect
# rewrote `!seats.select { |sa| !sa.accessibility.blank? }.empty?` into
# `!seats.reject { |sa| sa.accessibility.blank? }.empty?` (Style/InverseMethods).
# These are equivalent; this pins that behavior across both branches of the method.
RSpec.describe TicketOrder, '#wheelchair_requested?' do
  subject(:order) { described_class.new }

  def seat(accessibility)
    instance_double(SeatAssignment, accessibility: accessibility)
  end

  def stub_seating(reserved:, seats: [])
    production = instance_double(Production, has_reserved_seating?: reserved)
    performance = instance_double(Performance, production: production)
    allow(order).to receive(:performance).and_return(performance)
    allow(order).to receive(:seats).and_return(seats)
  end

  context 'via the special_request field' do
    it 'is true for a no-transfer wheelchair request' do
      order.special_request = TicketOrder::WHEELCHAIR
      expect(order.wheelchair_requested?).to be true
    end

    it 'is true for a can-transfer wheelchair request' do
      order.special_request = TicketOrder::WHEELCHAIR_TRANSFER
      expect(order.wheelchair_requested?).to be true
    end

    it 'is false for an unrelated request when not reserved seating' do
      order.special_request = TicketOrder::STAIRS
      stub_seating(reserved: false)
      expect(order.wheelchair_requested?).to be false
    end
  end

  context 'via a reserved-seating accessibility seat' do
    before { order.special_request = nil }

    it 'is true when at least one assigned seat has an accessibility value' do
      stub_seating(reserved: true, seats: [seat(nil), seat('wheelchair')])
      expect(order.wheelchair_requested?).to be true
    end

    it 'is false when no assigned seat has an accessibility value' do
      stub_seating(reserved: true, seats: [seat(nil), seat('')])
      expect(order.wheelchair_requested?).to be false
    end

    it 'is false for general admission even with an accessibility seat' do
      stub_seating(reserved: false, seats: [seat('wheelchair')])
      expect(order.wheelchair_requested?).to be false
    end
  end
end
