# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LglBackfillLinks do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:client) { instance_double(Lgl::Client) }
  let(:untagged) { FactoryBot.create(:address) }
  let(:tagged) { FactoryBot.create(:address) }
  let(:conflicting) { FactoryBot.create(:address) }
  let(:repointable) { FactoryBot.create(:address) }

  before do
    allow(Lgl).to receive(:enabled?).and_return(true)
    allow(Lgl).to receive(:client).and_return(client)
    allow(Resque).to receive(:enqueue)
    tagged.set_lgl_id!(900_002)
    conflicting.set_lgl_id!(900_099)
    repointable.set_lgl_id!(900_006)
    constituents = [
      { 'id' => 900_001, 'external_constituent_id' => untagged.id.to_s },
      { 'id' => 900_002, 'external_constituent_id' => tagged.id.to_s },
      { 'id' => 900_003, 'external_constituent_id' => '900003' },
      { 'id' => 900_004, 'external_constituent_id' => '999999999' },
      { 'id' => 900_005, 'external_constituent_id' => '' },
      { 'id' => 900_006, 'external_constituent_id' => '999999998' },
      { 'id' => 900_007, 'external_constituent_id' => conflicting.id.to_s }
    ]
    allow(client).to receive(:each_constituent) { |&block| constituents.each(&block) }
  end

  it 'writes local tags and reviews only, and counts each outcome' do
    counts = described_class.perform

    expect(counts).to eq(tagged: 1, already_tagged: 1, self_referencing: 1, dead_external_id: 2,
                         blank_external_id: 1, review: 1)
    expect(untagged.lgl_id).to eq('900001')
    expect(conflicting.lgl_review_reason).to eq('Also LGL constituent 900007')
  end

  it 'makes no LGL writes and enqueues nothing' do
    expect(client).not_to receive(:create)
    expect(client).not_to receive(:update)

    described_class.perform

    expect(Resque).not_to have_received(:enqueue)
    expect(repointable.lgl_id).to eq('900006')
  end

  it 'does nothing when LGL is disabled: no LGL call, no tags' do
    allow(Lgl).to receive(:enabled?).and_return(false)

    expect { expect(described_class.perform).to eq({}) }.not_to change(AddressTag, :count)

    expect(Lgl).not_to have_received(:client)
  end

  describe '.link_by_email' do
    def person(last_name, email, **attrs)
      FactoryBot.create(:address, full_name: "Pat #{last_name}", last_name: last_name, email: email, **attrs)
    end

    let(:smith) { person('Smith', 'smith@example.com') }
    let(:jones) { person('Jones', 'jones@example.com') }
    let(:jones_twin) { person('JONES', 'jones@example.com') }
    let(:linked) { person('Linked', 'linked@example.com') }
    let(:other_lgl) { person('Other', 'other@example.com') }
    let(:placeholder) { person('Held', 'held@example.com', placeholder: true) }

    def lgl(id, external_id, last_name, *emails)
      { 'id' => id, 'external_constituent_id' => external_id, 'last_name' => last_name,
        'email_addresses' => emails.map { |e| { 'address' => e } } }
    end

    let(:search_results) do
      [
        lgl(910_001, '', 'smith', 'other-addr@example.com', 'SMITH@example.com'), # one match
        lgl(910_002, '910002', 'Jones', 'jones@example.com'),                      # several (self-referencing)
        lgl(910_003, '999999997', 'Nobody', 'nobody@example.com'),                 # none (dead)
        lgl(910_004, '', 'Silent'),                                                # no email
        lgl(910_005, linked.id.to_s, 'Linked', 'linked@example.com'),              # live external: skipped
        lgl(910_006, '', 'Other', 'other@example.com'),                            # tagged other LGL ID
        lgl(910_007, '', 'Held', 'held@example.com'),                              # placeholder only
        lgl(910_001, '', 'smith', 'smith@example.com')                             # repeated by paging
      ]
    end

    before do
      smith
      jones
      jones_twin
      placeholder
      other_lgl.set_lgl_id!(910_099)
      allow(client).to receive(:search_updated_since).with(described_class::LINK_SCAN_FROM)
                                                     .and_return(search_results.each)
    end

    let(:expected_counts) do
      { %i[blank_external_id one_match] => 1, %i[self_referencing several_matches] => 1,
        %i[dead_external_id no_match] => 1, %i[blank_external_id no_email] => 1,
        %i[blank_external_id no_match] => 2 }
    end

    it 'enqueues a link sync for each constituent with exactly one candidate, and counts' do
      expect(described_class.link_by_email).to eq(expected_counts)

      expect(Resque).to have_received(:enqueue).once
      expect(Resque).to have_received(:enqueue).with(LglSyncAddressJob, smith.id, LglSyncAddressJob::LINK_TRIGGER)
    end

    it 'is what perform runs in link_by_email mode' do
      expect(described_class.perform('link_by_email')).to eq(expected_counts)
    end

    it 'counts the same but enqueues and writes nothing on a dry run' do
      expect(client).not_to receive(:update)

      expect(described_class.link_by_email(dry_run: true)).to eq(expected_counts)

      expect(Resque).not_to have_received(:enqueue)
    end

    it 'classifies junk external ids with Lgl::Reconciler.junk_kind' do
      allow(Lgl::Reconciler).to receive(:junk_kind).and_call_original

      described_class.link_by_email(dry_run: true)

      expect(Lgl::Reconciler).to have_received(:junk_kind).exactly(7).times
    end

    it 'matches an address already tagged with this same constituent' do
      smith.set_lgl_id!(910_001)

      expect(described_class.link_by_email(dry_run: true)[%i[blank_external_id one_match]]).to eq(1)
    end

    it 'does nothing when LGL is disabled' do
      allow(Lgl).to receive(:enabled?).and_return(false)

      expect(described_class.link_by_email).to eq({})

      expect(Lgl).not_to have_received(:client)
      expect(Resque).not_to have_received(:enqueue)
    end
  end
end
