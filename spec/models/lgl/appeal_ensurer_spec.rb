# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::AppealEnsurer do
  let(:client) { instance_double(Lgl::Client) }
  let(:ensurer) { described_class.new(client, campaign_id: 77, for_address_id: 5) }

  def appeal(id, name: '2026 Ticketing', campaign_id: 77, is_active: true)
    { 'id' => id, 'name' => name, 'campaign_id' => campaign_id, 'appeal_type_name' => 'Ticketing',
      'code' => '26TICKETING', 'is_active' => is_active }
  end

  before { allow(Rails.logger).to receive(:info) }

  it 'returns the remembered id without asking LGL' do
    LglSetting.store_season_appeal_id(2026, 900)

    expect(ensurer.ensure_for_season(2026)).to eq(900)
  end

  context 'when LGL already has the appeal' do
    it 'adopts it by name, remembers it, and makes no write when campaign and status match' do
      allow(client).to receive(:search_appeals).with('2026 Ticketing').and_return([appeal(31), appeal(12)])
      expect(client).not_to receive(:update_appeal)

      expect(ensurer.ensure_for_season(2026)).to eq(12)
      expect(LglSetting.season_appeal_id(2026)).to eq(12)
    end

    it 'leaves an appeal on a different campaign alone and remembers it' do
      allow(client).to receive(:search_appeals).and_return([appeal(12, campaign_id: 99)])
      expect(client).not_to receive(:update_appeal)

      expect(ensurer.ensure_for_season(2026)).to eq(12)
      expect(LglSetting.season_appeal_id(2026)).to eq(12)
    end

    it 'gives it the campaign when its campaign is blank' do
      allow(client).to receive(:search_appeals).and_return([appeal(12, campaign_id: nil)])
      expect(client).to receive(:update_appeal)
        .with(12, { name: '2026 Ticketing', is_active: true, campaign_id: 77 }, for_address_id: 5)

      expect(ensurer.ensure_for_season(2026)).to eq(12)
    end

    it 're-activates an inactive appeal without moving it off its campaign' do
      allow(client).to receive(:search_appeals).and_return([appeal(12, campaign_id: 99, is_active: false)])
      expect(client).to receive(:update_appeal)
        .with(12, { name: '2026 Ticketing', is_active: true }, for_address_id: 5)

      expect(ensurer.ensure_for_season(2026)).to eq(12)
    end
  end

  context 'when LGL has no appeal with the exact name' do
    before do
      allow(client).to receive(:search_appeals).and_return([appeal(40, name: '2026 Ticketing Extra')])
    end

    it 'creates one with the exact payload and remembers it' do
      expect(client).to receive(:create_appeal)
        .with({ name: '2026 Ticketing', campaign_id: 77, appeal_type_name: 'Ticketing',
                code: '26TICKETING', is_active: true }, for_address_id: 5)
        .and_return(appeal(55))

      expect(ensurer.ensure_for_season(2026)).to eq(55)
      expect(LglSetting.season_appeal_id(2026)).to eq(55)
    end

    it 'pads the code for single-digit years' do
      expect(client).to receive(:create_appeal).with(hash_including(code: '05TICKETING'), for_address_id: 5)
                                               .and_return(appeal(56))

      ensurer.ensure_for_season(2005)
    end

    it 'returns nil and remembers nothing when the read-only guard skips the create' do
      allow(client).to receive(:create_appeal).and_return(nil)

      expect(ensurer.ensure_for_season(2026)).to be_nil
      expect(LglSetting.season_appeal_id(2026)).to be_nil
    end
  end
end
