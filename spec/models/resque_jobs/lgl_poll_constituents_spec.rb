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

  it 'does nothing when LGL is disabled' do
    allow(Lgl).to receive(:enabled?).and_return(false)
    expect(described_class.perform).to be_nil
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
