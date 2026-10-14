# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LglPollConstituents do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:client) { instance_double(Lgl::Client) }
  let(:watermark) { Time.utc(2026, 10, 1, 12, 0, 0) }
  let(:address) { FactoryBot.create(:address) }

  before do
    allow(Lgl).to receive(:enabled?).and_return(true)
    allow(Lgl).to receive(:client).and_return(client)
    allow(Resque).to receive(:enqueue)
  end

  def stub_constituents(*constituents)
    allow(client).to receive(:search_updated_since) do |_time, &block|
      constituents.each(&block)
    end
  end

  def polled_through
    JobMetadata.last_run(described_class::WATERMARK)
  end

  it 'does nothing when LGL is disabled: no LGL call, watermark untouched' do
    JobMetadata.record_run_at(described_class::WATERMARK, watermark)
    allow(Lgl).to receive(:enabled?).and_return(false)

    expect { expect(described_class.perform).to be_nil }.not_to(change { polled_through })

    expect(Lgl).not_to have_received(:client)
    expect(Resque).not_to have_received(:enqueue)
  end

  it 'searches from five minutes before the watermark' do
    JobMetadata.record_run_at(described_class::WATERMARK, watermark)
    stub_constituents

    described_class.perform

    expect(client).to have_received(:search_updated_since).with(watermark - 5.minutes)
  end

  it 'reconciles each constituent and advances the watermark to the newest updated_at' do
    JobMetadata.record_run_at(described_class::WATERMARK, watermark)
    stub_constituents(
      { 'id' => 50, 'external_constituent_id' => address.id.to_s, 'updated_at' => '2026-10-01T13:00:00Z' },
      { 'id' => 51, 'external_constituent_id' => '', 'updated_at' => '2026-10-01T12:30:00Z' }
    )

    counts = described_class.perform

    expect(counts).to eq(tagged: 1, blank_external_id: 1)
    expect(address.lgl_id).to eq('50')
    expect(polled_through).to eq(Time.utc(2026, 10, 1, 13, 0, 0))
  end

  context 'when a linked constituent has a newer preferred street' do
    def changed(external_id)
      { 'id' => 979_629, 'external_constituent_id' => external_id, 'updated_at' => '2026-10-13T12:00:00Z',
        'first_name' => address.first_name, 'last_name' => address.last_name,
        'street_addresses' => [{ 'id' => 2, 'street' => '6924 N Sheridan Rd', 'city' => 'Chicago', 'state' => 'IL',
                                 'postal_code' => '60657-3205', 'is_preferred' => true,
                                 'updated_at' => '2026-10-13T12:00:00Z' }] }
    end

    before do
      allow(Resque).to receive(:enqueue_in)
      address.set_lgl_id!(979_629)
      address.update_column(:updated_at, Time.zone.parse('2026-10-01T12:00:00Z'))
    end

    it 'pulls it into the address and counts it as pulled' do
      stub_constituents(changed(address.id.to_s))

      expect(described_class.perform).to eq(pulled: 1)

      address.reload
      expect([address.line1, address.city, address.zipcode]).to eq(['6924 N Sheridan Rd', 'Chicago', '60657-3205'])
      expect(Resque).not_to have_received(:enqueue_in)
    end

    it 'never pulls when the external id is blank' do
      stub_constituents(changed(''))
      line1 = address.line1

      expect(described_class.perform).not_to have_key(:pulled)
      expect(address.reload.line1).to eq(line1)
    end
  end

  it 'leaves the watermark unchanged when nothing is newer' do
    JobMetadata.record_run_at(described_class::WATERMARK, watermark)
    stub_constituents

    described_class.perform

    expect(polled_through).to eq(watermark)
  end

  it 'leaves the watermark unchanged when LGL fails part-way' do
    JobMetadata.record_run_at(described_class::WATERMARK, watermark)
    allow(client).to receive(:search_updated_since) do |_time, &block|
      block.call({ 'id' => 50, 'external_constituent_id' => '', 'updated_at' => '2026-10-01T13:00:00Z' })
      raise Lgl::Error.new(status: 500)
    end

    expect { described_class.perform }.to raise_error(Lgl::Error)
    expect(polled_through).to eq(watermark)
  end
end
