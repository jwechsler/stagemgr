require 'rails_helper'

# The dynamic pricing trigger predicates and their validations. `available` is
# the on/off switch the shift flips; the predicates only say whether a shift is
# due -- Performance#scan_ticket_allocation_triggers does the flipping.
RSpec.describe TicketClassAllocation do
  let(:production)  { FactoryBot.create(:production, capacity: 10) }
  let(:performance) { FactoryBot.create(:performance, production: production, performance_date: Date.current + 10.days) }
  let(:source) { ladder_class('TCASRC') }
  let(:target) { ladder_class('TCATGT') }

  def ladder_class(code)
    FactoryBot.create(:ticket_class, production: production, class_code: code, class_name: code,
                                     ticket_price: 10, auto_attach: false, web_visible: true, holds_seats: true)
  end

  def allocation(attrs = {})
    source # lazy let: materialize before the production's classes are reloaded
    production.ticket_classes.reload
    performance.save! # populate rows for the new classes
    TicketClassAllocation.find_by!(performance_id: performance.id, ticket_class_id: source.id).tap do |tca|
      tca.assign_attributes(attrs)
    end
  end

  describe 'validations' do
    it 'needs no trigger settings while not shiftable' do
      expect(allocation(shiftable: false, shift_to_code: nil)).to be_valid
    end

    it 'requires a target when shiftable' do
      tca = allocation(shiftable: true, shift_to_code: nil, shift_when_capacity_over: 50)

      expect(tca).not_to be_valid
      expect(tca.errors[:shift_to_code]).to be_present
    end

    it 'requires at least one threshold when shiftable' do
      tca = allocation(shiftable: true, shift_to_code: target.class_code)

      expect(tca).not_to be_valid
      expect(tca.errors[:shift_when_capacity_over]).to be_present
      expect(tca.errors[:shift_days_before_performance]).to be_present
    end

    it 'accepts either threshold alone' do
      expect(allocation(shiftable: true, shift_to_code: target.class_code, shift_when_capacity_over: 50)).to be_valid
      expect(allocation(shiftable: true, shift_to_code: target.class_code, shift_days_before_performance: 3)).to be_valid
    end
  end

  describe '#trigger_satisfied_by_capacity?' do
    it 'is false when no capacity threshold is set' do
      expect(allocation(shift_when_capacity_over: nil).trigger_satisfied_by_capacity?(9)).to be false
    end

    it 'compares seats held against production capacity as a percentage, inclusive' do
      tca = allocation(shift_when_capacity_over: 30)

      expect(tca.trigger_satisfied_by_capacity?(3)).to be true
      expect(tca.trigger_satisfied_by_capacity?(2)).to be false
    end

    it 'fires at exactly the threshold where float division would undershoot' do
      production.update!(capacity: 100)
      tca = allocation(shift_when_capacity_over: 29)

      expect(tca.trigger_satisfied_by_capacity?(29)).to be true
      expect(tca.trigger_satisfied_by_capacity?(28)).to be false
    end

    it 'never fires against a missing or zero capacity' do
      tca = allocation(shift_when_capacity_over: 50)
      allow(tca.performance.production).to receive(:capacity).and_return(0)
      expect(tca.trigger_satisfied_by_capacity?(5)).to be false

      allow(tca.performance.production).to receive(:capacity).and_return(nil)
      expect(tca.trigger_satisfied_by_capacity?(5)).to be false
    end

    it 'reads the live seats held when none are passed in' do
      tca = allocation(shift_when_capacity_over: 30)
      allow(tca.performance).to receive(:seats_held).and_return(4)

      expect(tca.trigger_satisfied_by_capacity?(nil)).to be true
    end
  end

  describe '#trigger_satisifed_by_current_date?' do
    it 'is false when no days-before threshold is set' do
      expect(allocation(shift_days_before_performance: nil).trigger_satisifed_by_current_date?).to be false
    end

    it 'is true once today is within the window, inclusive' do
      expect(allocation(shift_days_before_performance: 10).trigger_satisifed_by_current_date?).to be true
      expect(allocation(shift_days_before_performance: 9).trigger_satisifed_by_current_date?).to be false
    end
  end

  describe '#trigger_satisfied?' do
    it 'is false while not shiftable even when a threshold is met' do
      tca = allocation(shiftable: false, shift_to_code: target.class_code, shift_days_before_performance: 1000)

      expect(tca.trigger_satisfied?(0)).to be false
    end

    it 'fires on either threshold' do
      by_date = allocation(shiftable: true, shift_to_code: target.class_code, shift_days_before_performance: 1000,
                           shift_when_capacity_over: 90)
      by_capacity = allocation(shiftable: true, shift_to_code: target.class_code, shift_days_before_performance: 1,
                               shift_when_capacity_over: 30)

      expect(by_date.trigger_satisfied?(0)).to be true
      expect(by_capacity.trigger_satisfied?(3)).to be true
      expect(by_capacity.trigger_satisfied?(2)).to be false
    end

    it 'never shifts a class to itself' do
      tca = allocation(shiftable: true, shift_to_code: source.class_code, shift_days_before_performance: 1000)

      expect(tca.trigger_satisfied?(0)).to be false
    end
  end
end
