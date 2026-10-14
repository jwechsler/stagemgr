# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::GiftHistoryRefresh do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:address) { FactoryBot.create(:address) }
  let(:client) { instance_double(Lgl::Client) }
  let(:today) { Date.new(2026, 10, 14) }
  let(:last_year_gift) { { 'gift_type_name' => 'Gift', 'amount' => 25, 'date' => '2025-05-20' } }
  let(:this_year_gift) { { 'gift_type_name' => 'Gift', 'amount' => 25, 'date' => '2026-05-20' } }

  def refresh
    described_class.refresh(address, client: client, today: today)
  end

  before { allow(Rails.logger).to receive(:info) }

  it 'is :unlinked and asks LGL nothing for an address with no LGL ID' do
    expect(described_class.refresh(address, today: today)).to eq(:unlinked)
  end

  context 'when linked' do
    before { address.set_lgl_id!(42) }

    it 'is :gone and leaves the tag alone when LGL no longer has the constituent' do
      address.set_lgl_lapsed!('SYBUNT')
      allow(client).to receive(:gifts).with('42').and_return(nil)

      expect(refresh).to eq(:gone)
      expect(address.lgl_lapsed).to eq('SYBUNT')
    end

    it 'is :set and logs when the address becomes lapsed' do
      allow(client).to receive(:gifts).with('42').and_return([last_year_gift])

      expect(refresh).to eq(:set)
      expect(address.lgl_lapsed).to eq('LYBUNT')
      expect(Rails.logger).to have_received(:info).with("[LGL] address ##{address.id}: lapsed=LYBUNT")
    end

    it 'is :set when the lapse changes from LYBUNT to SYBUNT' do
      address.set_lgl_lapsed!('LYBUNT')
      allow(client).to receive(:gifts).and_return([last_year_gift])

      expect(described_class.refresh(address, client: client, today: today.next_year)).to eq(:set)
      expect(address.lgl_lapsed).to eq('SYBUNT')
    end

    it 'is :cleared and logs when the donor gives again' do
      address.set_lgl_lapsed!('LYBUNT')
      allow(client).to receive(:gifts).and_return([last_year_gift, this_year_gift])

      expect(refresh).to eq(:cleared)
      expect(address.lgl_lapsed).to be_nil
      expect(Rails.logger).to have_received(:info).with("[LGL] address ##{address.id}: lapsed=none")
    end

    it 'is :unchanged, writes nothing and logs nothing when the tag already matches' do
      address.set_lgl_lapsed!('LYBUNT')
      allow(client).to receive(:gifts).and_return([last_year_gift])
      allow(address).to receive(:set_lgl_lapsed!)

      expect(refresh).to eq(:unchanged)
      expect(address).not_to have_received(:set_lgl_lapsed!)
      expect(Rails.logger).not_to have_received(:info).with(/lapsed=/)
    end

    it 'is :unchanged for a current donor with no tag' do
      allow(client).to receive(:gifts).and_return([this_year_gift])

      expect(refresh).to eq(:unchanged)
      expect(address.lgl_lapsed).to be_nil
    end
  end
end
