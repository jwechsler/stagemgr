# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::EventEnsurer do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:client) { instance_double(Lgl::Client) }
  let(:ensurer) { described_class.new(client, campaign_id: 77, for_address_id: 5) }
  let(:production) do
    FactoryBot.create(:production, name: 'Adolescent Salvation', season: 2026,
                                   first_preview_at: Date.new(2026, 9, 10), press_opening_at: Date.new(2026, 9, 14),
                                   opening_at: Date.new(2026, 9, 14), closing_at: Date.new(2026, 10, 19))
  end
  let(:wanted) do
    { name: 'Adolescent Salvation', campaign_id: 77, is_active: true, date: '2026-09-10', end_date: '2026-10-19' }
  end

  def event(id, name: 'Adolescent Salvation', campaign_id: 77, date: '2026-09-10', end_date: '2026-10-19',
            is_active: true)
    { 'id' => id, 'name' => name, 'campaign_id' => campaign_id, 'date' => date, 'end_date' => end_date,
      'is_active' => is_active }
  end

  before { allow(Rails.logger).to receive(:info) }

  context 'with a stored event id' do
    before { production.update_column(:lgl_event_id, 1519) }

    it 'makes no write when the event is up to date' do
      allow(client).to receive(:find_event).with(1519).and_return(event(1519))
      expect(client).not_to receive(:update_event)

      expect(ensurer.ensure_for(production)).to eq(1519)
    end

    it 'fills in campaign and end date on a hand-made event' do
      allow(client).to receive(:find_event).and_return(event(1519, campaign_id: nil, end_date: nil))
      expect(client).to receive(:update_event).with(1519, wanted, for_address_id: 5)

      expect(ensurer.ensure_for(production)).to eq(1519)
    end

    it 'leaves an event on another campaign alone when dates and status match' do
      allow(client).to receive(:find_event).and_return(event(1519, campaign_id: 99))
      expect(client).not_to receive(:update_event)

      expect(ensurer.ensure_for(production)).to eq(1519)
    end

    it 'fills in a missing end date without moving the event off its campaign' do
      allow(client).to receive(:find_event).and_return(event(1519, campaign_id: 99, end_date: nil))
      expect(client).to receive(:update_event).with(1519, wanted.except(:campaign_id), for_address_id: 5)

      expect(ensurer.ensure_for(production)).to eq(1519)
    end

    it 'never patches a linked inactive event, clears the link and creates a new event' do
      expect(client).to receive(:find_event).with(1519).ordered.and_return(event(1519, is_active: false))
      expect(client).to receive(:search_events).with('Adolescent Salvation').ordered.and_return([])
      expect(client).to receive(:create_event).with(wanted, for_address_id: 5).ordered.and_return(event(2001))
      expect(client).not_to receive(:update_event)

      expect(ensurer.ensure_for(production)).to eq(2001)
      expect(production.reload.lgl_event_id).to eq(2001)
      expect(Rails.logger).to have_received(:info)
        .with("[LGL] production ##{production.id}: linked event 1519 is inactive; linking a new one")
    end

    it 'clears the id when LGL answers 404, then searches and creates' do
      allow(client).to receive_messages(find_event: nil, search_events: [])
      expect(client).to receive(:create_event).with(wanted, for_address_id: 5).and_return(event(2001))

      expect(ensurer.ensure_for(production)).to eq(2001)
      expect(production.reload.lgl_event_id).to eq(2001)
    end
  end

  context 'without a stored event id' do
    it 'adopts an exact name match, stores it and reconciles it' do
      allow(client).to receive(:search_events).with('Adolescent Salvation')
                                              .and_return([event(1519, end_date: nil), event(1600, name: 'Adolescent Salvation 2')])
      expect(client).to receive(:update_event).with(1519, wanted.except(:campaign_id), for_address_id: 5)

      expect(ensurer.ensure_for(production)).to eq(1519)
      expect(production.reload.lgl_event_id).to eq(1519)
    end

    it 'prefers the duplicate dated in the production season' do
      allow(client).to receive(:search_events)
        .and_return([event(1700, date: '2024-01-01'), event(1519), event(1800, date: '2025-01-01')])

      expect(ensurer.ensure_for(production)).to eq(1519)
    end

    it 'falls back to the highest id when no duplicate is in season' do
      allow(client).to receive(:search_events)
        .and_return([event(1700, date: '2024-01-01'), event(1800, date: '2025-01-01')])
      allow(client).to receive(:update_event)

      expect(ensurer.ensure_for(production)).to eq(1800)
    end

    it 'creates a new event when the only exact name match is inactive' do
      allow(client).to receive(:search_events).and_return([event(1519, is_active: false)])
      expect(client).not_to receive(:update_event)
      expect(client).to receive(:create_event).with(wanted, for_address_id: 5).and_return(event(2001))

      expect(ensurer.ensure_for(production)).to eq(2001)
      expect(production.reload.lgl_event_id).to eq(2001)
    end

    it 'adopts the active exact name match over an inactive one whatever their dates and ids' do
      allow(client).to receive(:search_events)
        .and_return([event(1900, is_active: false), event(1500, date: '2024-01-01')])
      allow(client).to receive(:update_event)

      expect(ensurer.ensure_for(production)).to eq(1500)
      expect(production.reload.lgl_event_id).to eq(1500)
    end

    it 'creates the event with the exact payload and stores its id' do
      allow(client).to receive(:search_events).and_return([])
      expect(client).to receive(:create_event).with(wanted, for_address_id: 5).and_return(event(2001))

      expect(ensurer.ensure_for(production)).to eq(2001)
      expect(production.reload.lgl_event_id).to eq(2001)
    end

    it 'stores nothing when the read-only guard skips the create' do
      allow(client).to receive_messages(search_events: [], create_event: nil)

      expect(ensurer.ensure_for(production)).to be_nil
      expect(production.reload.lgl_event_id).to be_nil
    end

    it 'omits date and end date for a production with no dates' do
      production.update_columns(first_preview_at: nil, press_opening_at: nil, opening_at: nil, closing_at: nil)
      allow(client).to receive(:search_events).and_return([])
      expect(client).to receive(:create_event)
        .with({ name: 'Adolescent Salvation', campaign_id: 77, is_active: true }, for_address_id: 5)
        .and_return(event(2002))

      expect(ensurer.ensure_for(production)).to eq(2002)
    end
  end
end
