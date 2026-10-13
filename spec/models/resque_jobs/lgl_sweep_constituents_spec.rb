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
    present.set_lgl_id!(10)
    missing.set_lgl_id!(20)
  end

  it 'aborts without touching tags when the listing is incomplete' do
    allow(client).to receive(:each_constituent_id).and_return([[10], 3])
    allow(client).to receive(:find)

    expect { described_class.perform }.to raise_error(Lgl::Error, /listed 1/)

    expect(client).not_to have_received(:find)
    expect(missing.lgl_id).to eq('20')
    expect(JobMetadata.find_by(job_name: described_class::COMPLETED)).to be_nil
  end

  it 'clears the tag and enqueues a sync only after LGL confirms a 404' do
    allow(client).to receive(:each_constituent_id).and_return([[10, 30], 2])
    allow(client).to receive(:find).with('20').and_return(nil)

    expect(described_class.perform).to eq(cleared: 1)

    expect(missing.lgl_id).to be_nil
    expect(present.lgl_id).to eq('10')
    expect(Resque).to have_received(:enqueue).once.with(LglSyncAddressJob, missing.id, 'sweep')
    expect(JobMetadata.find_by(job_name: described_class::COMPLETED)).to be_present
  end

  it 'keeps the tag when the direct lookup still finds the constituent' do
    allow(client).to receive(:each_constituent_id).and_return([[10], 1])
    allow(client).to receive(:find).with('20').and_return({ 'id' => 20 })

    expect(described_class.perform).to eq(still_present: 1)

    expect(missing.lgl_id).to eq('20')
    expect(Resque).not_to have_received(:enqueue)
  end

  it 'looks up nothing when every tag is listed' do
    allow(client).to receive(:each_constituent_id).and_return([[10, 20], 2])
    allow(client).to receive(:find)

    expect(described_class.perform).to eq({})
    expect(client).not_to have_received(:find)
  end
end
