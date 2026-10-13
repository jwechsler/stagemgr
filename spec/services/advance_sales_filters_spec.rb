# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdvanceSalesFilters, type: :service do
  let(:theaters) { [instance_double(Theater, id: 11), instance_double(Theater, id: 12)] }
  let(:seasons)  { [2026, 2025, 2024] }

  def filters(params = {})
    described_class.new(ActionController::Parameters.new(params), theaters: theaters, seasons: seasons)
  end

  it 'defaults to the two latest seasons, every permitted theater, compare by season and both segments ' \
     'when nothing was submitted' do
    result = filters

    expect(result.submitted?).to be(false)
    expect(result.valid?).to be(true)
    expect(result.to_h).to eq(theater_ids: [11, 12], seasons: [2026, 2025], compare_by: 'season',
                              segment: 'both', include_external: false)
  end

  it 'keeps only theaters and seasons the user may pick' do
    result = filters(theater_ids: ['', '12', '99'], seasons: ['', '2024', '1999'])

    expect(result.theater_ids).to eq([12])
    expect(result.seasons).to eq([2024])
    expect(result.valid?).to be(true)
  end

  it 'treats an empty theater selection as every permitted theater' do
    expect(filters(theater_ids: [''], seasons: ['2025']).theater_ids).to eq([11, 12])
    expect(filters(theater_ids: ['99'], seasons: ['2025']).theater_ids).to eq([11, 12])
  end

  it 'exposes the theaters the user actually picked' do
    result = filters(theater_ids: ['11'], seasons: ['2025'])

    expect(result.picked_theater_ids).to eq([11])
    expect(result.theater_ids).to eq([11])
  end

  it 'exposes no picked theaters when none were submitted' do
    result = filters(seasons: ['2025'])

    expect(result.picked_theater_ids).to eq([])
    expect(result.theater_ids).to eq([11, 12])
  end

  it 'exposes no picked theaters when every submitted theater is out of reach' do
    result = filters(theater_ids: ['', '99'], seasons: ['2025'])

    expect(result.picked_theater_ids).to eq([])
    expect(result.theater_ids).to eq([11, 12])
  end

  it 'rejects a submission with no seasons' do
    result = filters(seasons: [''])

    expect(result.submitted?).to be(true)
    expect(result.valid?).to be(false)
    expect(result.error).to eq('Select at least one season.')
    expect(result.seasons).to eq([])
  end

  it 'falls back to defaults for unknown compare_by and segment values' do
    result = filters(seasons: ['2025'], compare_by: 'venue', segment: 'comp')

    expect(result.compare_by).to eq('season')
    expect(result.segment).to eq('both')
  end

  it 'keeps known compare_by and segment values' do
    result = filters(seasons: ['2025'], compare_by: 'production', segment: 'pass')

    expect(result.compare_by).to eq('production')
    expect(result.segment).to eq('pass')
  end

  it "reads include_external from '1'" do
    expect(filters(seasons: ['2025'], include_external: '1').include_external).to be(true)
    expect(filters(seasons: ['2025'], include_external: '0').include_external).to be(false)
    expect(filters(seasons: ['2025']).include_external).to be(false)
  end
end
