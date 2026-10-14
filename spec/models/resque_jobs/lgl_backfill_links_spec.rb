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

  describe '.replicate' do
    def lgl(id, external_id, last_name, *emails)
      { 'id' => id, 'external_constituent_id' => external_id, 'first_name' => 'Pat', 'last_name' => last_name,
        'email_addresses' => emails.map { |e| { 'address' => e } } }
    end

    let(:matched) { FactoryBot.create(:address, full_name: 'Pat Match', last_name: 'Match', email: 'match@example.com') }
    let(:retagged) { FactoryBot.create(:address) }
    let(:search_results) do
      [
        lgl(930_001, '', 'Newcomer', 'new@example.com'),                 # created
        lgl(930_002, '930002', 'Match', 'match@example.com'),            # linked
        lgl(930_003, '', 'Org', 'org@example.com').merge('is_org' => true), # org_skipped
        lgl(930_004, '999999996', 'Tagged'),                             # repointed
        lgl(930_005, untagged.id.to_s, 'Live', 'live@example.com'),      # live external: skipped
        lgl(930_006, '', 'Second', 'second@example.com'),                # created
        lgl(930_001, '', 'Newcomer', 'new@example.com')                  # repeated by paging
      ]
    end

    before do
      matched
      retagged.set_lgl_id!(930_004)
      Lgl.read_write!
      allow(Resque).to receive(:enqueue_in)
      allow(client).to receive(:search_updated_since).with(described_class::LINK_SCAN_FROM)
                                                     .and_return(search_results.each)
    end

    it 'links, creates, skips and re-points, staggering the syncs' do
      counts = nil
      expect { counts = described_class.replicate }.to change(Address, :count).by(2)

      expect(counts).to eq(created: 2, linked: 1, org_skipped: 1, repointed: 1)
      newcomer = Address.find_by(email: 'new@example.com')
      second = Address.find_by(email: 'second@example.com')
      expect([newcomer.lgl_id, matched.lgl_id]).to eq(%w[930001 930002])
      link = LglSyncAddressJob::LINK_TRIGGER
      expect(Resque).to have_received(:enqueue_in).with(0.seconds, LglSyncAddressJob, newcomer.id, link).ordered
      expect(Resque).to have_received(:enqueue_in).with(3.seconds, LglSyncAddressJob, matched.id, link).ordered
      expect(Resque).to have_received(:enqueue_in).with(6.seconds, LglSyncAddressJob, retagged.id, link).ordered
      expect(Resque).to have_received(:enqueue_in).with(9.seconds, LglSyncAddressJob, second.id, link).ordered
      expect(Resque).not_to have_received(:enqueue)
    end

    after { Lgl.read_write! }

    context 'when LGL is read-only' do
      it 'links and creates locally but enqueues no sync, counting the skipped ones' do
        Lgl.read_only!
        counts = nil
        expect { counts = described_class.replicate }.to change(Address, :count).by(2)

        expect(counts).to eq(created: 2, linked: 1, org_skipped: 1, repointed: 1, sync_skipped_readonly: 4)
        expect(Address.find_by(email: 'new@example.com').lgl_id).to eq('930001')
        expect(matched.lgl_id).to eq('930002')
        expect(Resque).not_to have_received(:enqueue_in)
        expect(Resque).not_to have_received(:enqueue)
      end

      it 'still reports the address id of each linked or created address' do
        Lgl.read_only!
        rows = []
        described_class.replicate { |*row| rows << row }

        expect(rows).to include(['930002', 'Pat Match', :linked, matched.id], ['930004', 'Pat Tagged', :repointed, retagged.id])
      end

      it 'enqueues an allowlisted address at once, without staggering, and skips the others' do
        Lgl.read_only!(except_address_ids: [matched.id])

        expect(described_class.replicate).to include(linked: 1, sync_skipped_readonly: 3)
        expect(Resque).to have_received(:enqueue).once
        expect(Resque).to have_received(:enqueue).with(LglSyncAddressJob, matched.id, LglSyncAddressJob::LINK_TRIGGER)
        expect(Resque).not_to have_received(:enqueue_in)
      end
    end

    it 'lists every constituent before enqueuing anything' do
      listed = false
      allow(client).to receive(:search_updated_since) do
        Enumerator.new do |yielder|
          search_results.each { |c| yielder << c }
          listed = true
        end
      end
      allow(Resque).to receive(:enqueue_in) { expect(listed).to be(true) }

      described_class.replicate
    end

    it 'yields one row per junk constituent' do
      rows = []
      described_class.replicate { |*row| rows << row }

      newcomer = Address.find_by(email: 'new@example.com')
      expect(rows.first).to eq(['930001', 'Pat Newcomer', :created, newcomer.id])
      expect(rows.map(&:first)).to eq(%w[930001 930002 930003 930004 930006])
    end

    context 'with constituent ids' do
      before do
        search_results.each { |c| allow(client).to receive(:find).with(c['id'].to_s).and_return(c) }
        allow(client).to receive(:find).with('930099').and_return(nil)
      end

      it 'limits the run to the given constituent ids' do
        expect(described_class.replicate(constituent_ids: %w[930002 930004])).to eq(linked: 1, repointed: 1)
        expect(Address.find_by(email: 'new@example.com')).to be_nil
      end

      it 'fetches each id with find instead of listing every constituent' do
        described_class.replicate(constituent_ids: %w[930002 930004])

        expect(client).to have_received(:find).with('930002')
        expect(client).to have_received(:find).with('930004')
        expect(client).not_to have_received(:search_updated_since)
      end

      it 'skips an id LGL does not find, without raising' do
        allow(Rails.logger).to receive(:info)

        expect(described_class.replicate(constituent_ids: %w[930099 930002])).to eq(linked: 1)
        expect(Rails.logger).to have_received(:info).with('[LGL] replicate: constituent 930099 not found')
      end

      it 're-points a tagged junk constituent with LINK_TRIGGER, never a reason that may create' do
        described_class.replicate(constituent_ids: %w[930004])

        expect(Resque).to have_received(:enqueue_in)
          .with(0.seconds, LglSyncAddressJob, retagged.id, LglSyncAddressJob::LINK_TRIGGER)
      end
    end

    it 'reports the same outcomes on a dry run but writes and enqueues nothing' do
      rows = []
      counts = nil
      expect { counts = described_class.replicate(dry_run: true) { |*row| rows << row } }
        .not_to(change { [Address.count, AddressTag.count] })

      expect(counts).to eq(created: 2, linked: 1, org_skipped: 1, repointed: 1)
      expect(rows).to include(['930002', 'Pat Match', :linked, matched.id], ['930004', 'Pat Tagged', :repointed, retagged.id])
      expect(matched.lgl_id).to be_nil
      expect(Resque).not_to have_received(:enqueue_in)
    end

    it 'lists an email Address would reject as invalid_email on a dry run' do
      allow(client).to receive(:search_updated_since).and_return([lgl(930_007, '', 'Bad', 'bad@@example..com')].each)

      expect(described_class.replicate(dry_run: true)).to eq(invalid_email: 1)
    end

    it 'is what perform runs in replicate mode' do
      expect(described_class.perform('replicate')).to eq(created: 2, linked: 1, org_skipped: 1, repointed: 1)
    end

    it 'does nothing when LGL is disabled' do
      allow(Lgl).to receive(:enabled?).and_return(false)

      expect(described_class.replicate).to eq({})
      expect(Lgl).not_to have_received(:client)
    end
  end
end
