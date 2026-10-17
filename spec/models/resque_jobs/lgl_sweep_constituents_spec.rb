# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LglSweepConstituents do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:client) { instance_double(Lgl::Client) }
  let(:present) { FactoryBot.create(:address) }
  let(:missing) { FactoryBot.create(:address) }

  before do
    allow(Lgl).to receive(:enabled?).and_return(true)
    allow(Lgl).to receive(:client).and_return(client)
    allow(Resque).to receive(:enqueue)
    present.set_lgl_id!(900_010)
    missing.set_lgl_id!(900_020)
  end

  it 'does nothing when LGL is disabled: no LGL call, tags and completion mark untouched' do
    allow(Lgl).to receive(:enabled?).and_return(false)

    expect(described_class.perform).to be_nil

    expect(Lgl).not_to have_received(:client)
    expect(Resque).not_to have_received(:enqueue)
    expect(missing.lgl_id).to eq('900020')
    expect(JobMetadata.find_by(job_name: described_class::COMPLETED)).to be_nil
  end

  it 'aborts without touching tags when the listing is incomplete' do
    allow(client).to receive(:each_constituent_id).and_return([[900_010], 3])
    allow(client).to receive(:find)

    expect { described_class.perform }.to raise_error(Lgl::Error, /listed 1/)

    expect(client).not_to have_received(:find)
    expect(missing.lgl_id).to eq('900020')
    expect(JobMetadata.find_by(job_name: described_class::COMPLETED)).to be_nil
  end

  it 'keeps the dead tag and enqueues a sync only after LGL confirms a 404' do
    allow(client).to receive(:each_constituent_id).and_return([[900_010, 900_030], 2])
    allow(client).to receive(:find).with('900020').and_return(nil)

    expect(described_class.perform).to eq(dead: 1)

    expect(missing.lgl_id).to eq('900020')
    expect(present.lgl_id).to eq('900010')
    expect(Resque).to have_received(:enqueue).once.with(LglSyncAddressJob, missing.id, 'sweep')
    expect(JobMetadata.find_by(job_name: described_class::COMPLETED)).to be_present
  end

  it 'keeps the tag when the direct lookup still finds the constituent' do
    allow(client).to receive(:each_constituent_id).and_return([[900_010], 1])
    allow(client).to receive(:find).with('900020').and_return({ 'id' => 900_020 })

    expect(described_class.perform).to eq(still_present: 1)

    expect(missing.lgl_id).to eq('900020')
    expect(Resque).not_to have_received(:enqueue)
  end

  it 'looks up nothing when every tag is listed' do
    allow(client).to receive(:each_constituent_id).and_return([[900_010, 900_020], 2])
    allow(client).to receive(:find)

    expect(described_class.perform).to eq({})
    expect(client).not_to have_received(:find)
  end
end
