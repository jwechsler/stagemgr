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

  describe 'resolved merge reviews' do
    let(:merge_reason) { 'Also LGL constituent 900099: merge the two in LGL' }

    before { allow(client).to receive(:find) }

    def list(*ids)
      allow(client).to receive(:each_constituent_id).and_return([ids, ids.size])
    end

    ['Also LGL constituent 900099', 'Also LGL constituent 900099: merge the two in LGL'].each do |reason|
      it "clears #{reason.inspect} once LGL confirms 900099 is a 404 and the address's LGL ID is listed" do
        list(900_010, 900_020)
        allow(client).to receive(:find).with('900099').and_return(nil)
        present.lgl_review!(reason)

        expect(described_class.perform).to eq(merge_review_cleared: 1)

        expect(present.lgl_review_reason).to be_nil
        expect(present.lgl_id).to eq('900010')
        expect(client).to have_received(:find).once.with('900099')
        expect(Resque).not_to have_received(:enqueue)
      end
    end

    it 'keeps the review when the direct lookup still finds the named constituent' do
      list(900_010, 900_020)
      allow(client).to receive(:find).with('900099').and_return({ 'id' => 900_099 })
      present.lgl_review!(merge_reason)

      expect(described_class.perform).to eq(merge_review_kept: 1)

      expect(present.lgl_review_reason).to eq(merge_reason)
    end

    it "leaves the review to the dead-link pass when the address's own LGL ID is also missing" do
      list(900_010)
      allow(client).to receive(:find).with('900020').and_return(nil)
      missing.lgl_review!(merge_reason)

      expect(described_class.perform).to eq(dead: 1)

      expect(client).not_to have_received(:find).with('900099')
      expect(missing.lgl_review_reason).to eq(merge_reason)
      expect(Resque).to have_received(:enqueue).once.with(LglSyncAddressJob, missing.id, 'sweep')
    end

    it 'looks up nothing when the named constituent is listed' do
      list(900_010, 900_020, 900_099)
      present.lgl_review!(merge_reason)

      expect(described_class.perform).to eq({})

      expect(client).not_to have_received(:find)
      expect(present.lgl_review_reason).to eq(merge_reason)
    end

    it 'keeps a newer review written between the listing and the lookup' do
      list(900_010, 900_020)
      present.lgl_review!(merge_reason)
      allow(client).to receive(:find).with('900099') do
        present.lgl_review!('Also LGL constituent 900077')
        nil
      end

      expect(described_class.perform).to eq(merge_review_changed: 1)

      expect(present.lgl_review_reason).to eq('Also LGL constituent 900077')
    end

    it 'counts the address as gone when it disappears during the lookup' do
      list(900_010, 900_020)
      present.lgl_review!(merge_reason)
      allow(client).to receive(:find).with('900099').and_return(nil)
      allow(Address).to receive(:find_by).and_call_original
      allow(Address).to receive(:find_by).with(id: present.id).and_return(nil)

      expect(described_class.perform).to eq(address_gone: 1)
    end

    it 'leaves every other review reason untouched' do
      list(900_010, 900_020)
      present.lgl_review!('LGL constituent 900099 is also linked to #5678')
      missing.lgl_review!('LGL constituent 900099 matches several customers by email and last name')

      expect(described_class.perform).to eq({})

      expect(client).not_to have_received(:find)
      expect(present.lgl_review_reason).to eq('LGL constituent 900099 is also linked to #5678')
      expect(missing.lgl_review_reason).to eq('LGL constituent 900099 matches several customers by email and last name')
    end
  end
end
