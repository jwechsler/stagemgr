require 'rails_helper'

RSpec.describe Venue, type: :model do
  let(:venue) { FactoryBot.create(:venue) }

  def play(**attrs)
    FactoryBot.create(:production, {
      venue: venue,
      status: Production::ACTIVE,
      production_class: Production::PRIMETIME
    }.merge(attrs))
  end

  def dated(start, closing)
    { first_preview_at: start, press_opening_at: start, opening_at: start, closing_at: closing }
  end

  # Visible productions validate their dates, so a dateless one is legacy data.
  def undated_play
    play(**dated(Date.current, Date.current)).tap do |p|
      p.update_columns(first_preview_at: nil, press_opening_at: nil, opening_at: nil, closing_at: nil)
    end
  end

  # The pre-narrowing implementation: filter every production in Ruby.
  def old_now_playing(production_class, through = nil)
    venue.productions.to_a.select do |p|
      p.now_playing?(through) && p.visible? && p.production_class == production_class
    end
  end

  def old_next_up(production_class)
    venue.productions.to_a.select do |p|
      p.first_playing_date > Date.current && p.visible? && p.production_class == production_class
    end
  end

  def production_rows_loaded(&block)
    rows = 0
    callback = lambda do |*, payload|
      rows += payload[:record_count] if payload[:class_name] == 'Production'
    end
    ActiveSupport::Notifications.subscribed(callback, 'instantiation.active_record', &block)
    rows
  end

  context 'with current, closed, hidden, future, undated and off-time productions' do
    let!(:current) { play(**dated(Date.current - 1.week, Date.current + 1.week)) }
    let!(:closed) { play(**dated(Date.current - 2.months, Date.current - 1.month)) }
    let!(:hidden) { play(status: Production::INACTIVE, **dated(Date.current - 1.week, Date.current + 1.week)) }
    let!(:future) { play(**dated(Date.current + 1.month, Date.current + 2.months)) }
    let!(:undated) { undated_play }
    let!(:off_time) do
      play(production_class: Production::OFF_TIME, **dated(Date.current - 1.week, Date.current + 1.week))
    end

    it 'returns exactly what filtering every production in Ruby returns' do
      expect(venue.now_playing(Production::PRIMETIME)).to contain_exactly(*old_now_playing(Production::PRIMETIME))
      expect(venue.now_playing(Production::PRIMETIME)).to contain_exactly(current)
      expect(venue.now_playing(Production::OFF_TIME)).to contain_exactly(off_time)
    end

    it 'honours a wider through date the same way as the Ruby filter' do
      through = Date.current + 6.weeks
      expect(venue.now_playing(Production::PRIMETIME, through))
        .to contain_exactly(*old_now_playing(Production::PRIMETIME, through))
    end

    it 'does not load closed or hidden productions' do
      venue.reload
      rows = production_rows_loaded { venue.now_playing(Production::PRIMETIME) }
      # current, future and undated are not closed, visible and primetime
      expect(rows).to eq(3)
      expect(rows).to be < venue.productions.count
    end
  end

  context 'with nothing current' do
    let!(:closed) { play(**dated(Date.current - 2.months, Date.current - 1.month)) }
    let!(:hidden) { play(status: Production::INACTIVE, **dated(Date.current + 1.week, Date.current + 3.weeks)) }
    let!(:later) { play(**dated(Date.current + 2.months, Date.current + 3.months)) }
    let!(:soonest) { play(**dated(Date.current + 1.month, Date.current + 2.months)) }
    let!(:off_time) do
      play(production_class: Production::OFF_TIME, **dated(Date.current + 1.week, Date.current + 2.weeks))
    end

    it 'returns the soonest future production, as the Ruby filter would' do
      expected = old_next_up(Production::PRIMETIME).min_by(&:first_preview_at)
      expect(venue.now_playing_or_next_up(Production::PRIMETIME)).to eq([expected])
      expect(expected).to eq(soonest)
    end

    it 'keeps a production with no dates as a next-up candidate' do
      [later, soonest].each(&:destroy)
      undated = undated_play
      expect(old_next_up(Production::PRIMETIME)).to eq([undated])
      expect(venue.reload.now_playing_or_next_up(Production::PRIMETIME)).to eq([undated])
    end

    it 'does not load closed or hidden productions for the next-up set' do
      venue.reload
      rows = production_rows_loaded { venue.now_playing_or_next_up(Production::PRIMETIME) }
      # now_playing loads later and soonest (not closed); next-up loads them again
      expect(rows).to eq(4)
    end
  end
end
