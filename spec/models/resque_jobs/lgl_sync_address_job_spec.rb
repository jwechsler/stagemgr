# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LglSyncAddressJob do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:address) do
    FactoryBot.create(:address, first_name: 'Jane', last_name: 'Smith', full_name: 'Jane Smith', phone: nil,
                                line1: '1 Main St', city: 'Chicago', state: 'IL', zipcode: '60601')
  end
  let(:client) { instance_double(Lgl::Client) }

  # An LGL constituent that already matches the address exactly.
  def constituent(id, external_id: address.id.to_s, last_name: 'Smith')
    { 'id' => id, 'first_name' => address.first_name, 'last_name' => last_name,
      'external_constituent_id' => external_id,
      'email_addresses' => [{ 'id' => 1, 'address' => address.email, 'is_preferred' => true }],
      'street_addresses' => [{ 'id' => 2, 'street' => address.line1, 'city' => address.city,
                               'state' => address.state, 'postal_code' => address.zipcode, 'is_preferred' => true }],
      'phone_numbers' => [] }
  end

  before do
    allow(Lgl).to receive(:enabled?).and_return(true)
    allow(Lgl).to receive(:client).and_return(client)
    allow(client).to receive_messages(search_by_external_id: [], search_by_email: [])
    allow(Lgl::GiftHistoryRefresh).to receive(:refresh).and_return(:unchanged)
  end

  it 'does nothing when LGL is disabled: no LGL call, no tag, one log line' do
    allow(Lgl).to receive(:enabled?).and_return(false)
    allow(Rails.logger).to receive(:info)

    expect(described_class.perform(address.id)).to be_nil

    expect(Lgl).not_to have_received(:client)
    expect(address.lgl_id).to be_nil
    expect(address.lgl_review_reason).to be_nil
    expect(Rails.logger).to have_received(:info).with(a_string_including('skipped', 'littlegreenlight.sync')).once
  end

  it 'does nothing for a placeholder address' do
    address.update_column(:placeholder, true)
    expect(described_class.perform(address.id)).to be_nil
  end

  # resque-scheduler enqueues delayed jobs inside a Redis MULTI; a @loner's
  # enqueue-time lock check then raised NoMethodError (to_i on Redis::Future)
  # and the delayed sync was silently dropped.
  it 'takes no enqueue-time lock, only a perform-time one' do
    expect(described_class.instance_variable_get(:@loner)).to be_falsey
    expect(described_class.lock_timeout).to be_positive
  end

  it 'survives resque-scheduler moving a delayed run onto the maintenance queue' do
    allow(Resque::Scheduler).to receive(:am_master).and_return(true) # its master lock is Lua; fakeredis has none
    Resque.enqueue_in(2.minutes, described_class, address.id, described_class::EDIT_TRIGGER)
    timestamp = Resque.next_delayed_timestamp(2.minutes.from_now)

    Resque::Scheduler.enqueue_delayed_items_for_timestamp(timestamp)

    expect(Resque.peek(:maintenance)).to eq('class' => described_class.name,
                                            'args' => [address.id, described_class::EDIT_TRIGGER])
  end

  it 'uses one lock per address whatever the reason' do
    expect(described_class.redis_lock_key(5, 'donation')).to eq(described_class.redis_lock_key(5, 'manual'))
  end

  context 'when tagged' do
    before { address.set_lgl_id!(900_050) }

    it 'makes no write when LGL already matches' do
      allow(client).to receive(:find).with('900050').and_return(constituent(900_050))
      expect(client).not_to receive(:update)

      expect(described_class.perform(address.id).action).to eq(:unchanged)
    end

    it 'updates LGL when the external id differs' do
      allow(client).to receive(:find).and_return(constituent(900_050, external_id: ''))
      allow(client).to receive(:update)

      described_class.perform(address.id)

      expect(client).to have_received(:update)
        .with(900_050, hash_including(external_constituent_id: address.id.to_s), for_address_id: address.id)
    end

    it 'sends nothing on a donation sync when only the street differs' do
      allow(client).to receive(:find).and_return(constituent(900_050).merge('street_addresses' => []))
      expect(client).not_to receive(:update)

      described_class.perform(address.id, 'donation')
    end

    it "sends only the external id with LGL's own names and emails on a donation sync" do
      lgl = constituent(900_050, external_id: '').merge('first_name' => 'Janie', 'street_addresses' => [])
      allow(client).to receive(:find).and_return(lgl)
      allow(client).to receive(:update)

      described_class.perform(address.id, 'donation')

      expect(client).to have_received(:update)
        .with(900_050, { first_name: 'Janie', last_name: 'Smith', external_constituent_id: address.id.to_s,
                         email_addresses: lgl['email_addresses'] }, for_address_id: address.id)
    end

    context 'on an address-edit sync' do
      before do
        allow(client).to receive(:update)
        allow(client).to receive(:update_street_address)
        allow(client).to receive(:add_street_address)
        allow(client).to receive(:add_phone_number)
        allow(Rails.logger).to receive(:info)
      end

      let(:other_street) do
        { 'id' => 3, 'street' => '9 Work Rd', 'city' => 'Evanston', 'state' => 'IL', 'postal_code' => '60201',
          'is_preferred' => false }
      end

      it "edits only LGL's preferred street by id and keeps street out of the constituent PATCH" do
        lgl = constituent(900_050, external_id: '')
        lgl['street_addresses'] = [other_street, lgl['street_addresses'].first.merge('street' => '8 Old Rd')]
        allow(client).to receive(:find).and_return(lgl)

        described_class.perform(address.id, described_class::EDIT_TRIGGER)

        expect(client).to have_received(:update_street_address)
          .with(2, { street: '1 Main St', city: 'Chicago', state: 'IL', postal_code: '60601' },
                for_address_id: address.id)
        expect(client).to have_received(:update)
          .with(900_050, satisfy { |body| !body.key?(:street_addresses) && !body.key?(:phone_numbers) },
                for_address_id: address.id)
        expect(client).not_to have_received(:add_street_address)
      end

      it 'adds a preferred Home street when LGL has no preferred entry' do
        allow(client).to receive(:find).and_return(constituent(900_050).merge('street_addresses' => [other_street]))

        expect(described_class.perform(address.id, described_class::EDIT_TRIGGER).action).to eq(:updated)

        expect(client).to have_received(:add_street_address)
          .with(900_050, hash_including(street: '1 Main St', street_address_type_id: 1, is_preferred: true),
                for_address_id: address.id)
        expect(client).not_to have_received(:update)
        expect(client).not_to have_received(:update_street_address)
      end

      it 'logs the groups it is about to change before the first write, never their values' do
        address.update!(phone: '773-555-0100')
        lgl = constituent(900_050)
        lgl['street_addresses'].first['street'] = '8 Old Rd'
        allow(client).to receive(:find).and_return(lgl)

        described_class.perform(address.id, described_class::EDIT_TRIGGER)

        expect(Rails.logger).to have_received(:info)
          .with("[LGL] address ##{address.id}: before edit, constituent 900050 " \
                'changing street (preferred entry 2); phone (add preferred entry)').ordered
        expect(client).to have_received(:update_street_address).ordered
        expect(Rails.logger).not_to have_received(:info)
          .with(a_string_matching(/Jane|Smith|Main St|Old Rd|Chicago|60601|555/))
        expect(client).to have_received(:add_phone_number)
          .with(900_050, { number: '773-555-0100', phone_number_type_id: 1, is_preferred: true },
                for_address_id: address.id)
      end

      it 'names the constituent fields it is about to change, never their values' do
        allow(client).to receive(:find).and_return(constituent(900_050).merge('first_name' => 'Janie'))

        described_class.perform(address.id, described_class::EDIT_TRIGGER)

        expect(Rails.logger).to have_received(:info)
          .with(a_string_including("address ##{address.id}: before edit, constituent 900050 changing fields ",
                                   'first_name'))
        expect(Rails.logger).not_to have_received(:info).with(a_string_matching(/Jane|Smith/))
      end

      it 'writes and logs nothing when LGL already matches' do
        allow(client).to receive(:find).and_return(constituent(900_050))

        expect(described_class.perform(address.id, described_class::EDIT_TRIGGER).action).to eq(:unchanged)
        expect(client).not_to have_received(:update_street_address)
        expect(Rails.logger).not_to have_received(:info).with(/before edit/)
      end
    end

    it 'never touches street or phone entries on a non-edit sync' do
      address.update!(phone: '773-555-0100')
      lgl = constituent(900_050, external_id: '').merge('street_addresses' => [], 'phone_numbers' => [])
      allow(client).to receive(:find).and_return(lgl)
      allow(client).to receive(:update)

      %w[donation manual poll sweep].each { |reason| described_class.perform(address.id, reason) }

      expect(client).to have_received(:update).exactly(4).times
    end

    context 'when LGL has a newer preferred street' do
      before do
        address.update_column(:updated_at, Time.zone.parse('2026-10-01T12:00:00Z'))
        allow(client).to receive(:update)
        allow(client).to receive(:update_street_address)
      end

      def newer_lgl(external_id: address.id.to_s)
        lgl = constituent(900_050, external_id: external_id)
        lgl['street_addresses'].first.merge!('street' => '6924 N Sheridan Rd', 'postal_code' => '60657-3205',
                                             'updated_at' => '2026-10-13T12:00:00Z')
        lgl
      end

      it 'pulls it into Stagemgr on a manual Re-sync instead of overwriting LGL' do
        allow(client).to receive(:find).and_return(newer_lgl)

        outcome = described_class.perform(address.id, described_class::MANUAL_TRIGGER)

        expect(outcome.reason).to eq('tagged; pulled street')
        expect(address.reload.attributes.values_at('line1', 'zipcode')).to eq(['6924 N Sheridan Rd', '60657-3205'])
        expect(client).not_to have_received(:update)
        expect(client).not_to have_received(:update_street_address)
      end

      ['', '999999'].each do |external_id|
        it "does not pull on a manual Re-sync when LGL's external id is #{external_id.inspect}, but still re-points" do
          allow(client).to receive(:find).and_return(newer_lgl(external_id: external_id))

          described_class.perform(address.id, described_class::MANUAL_TRIGGER)

          expect(address.reload.line1).to eq('1 Main St')
          expect(client).to have_received(:update)
            .with(900_050, hash_including(external_constituent_id: address.id.to_s), for_address_id: address.id)
        end
      end

      it 'does not pull on an edit sync: Stagemgr pushes its own street' do
        allow(client).to receive(:find).and_return(newer_lgl)
        allow(Rails.logger).to receive(:info)

        described_class.perform(address.id, described_class::EDIT_TRIGGER)

        expect(address.reload.line1).to eq('1 Main St')
        expect(client).to have_received(:update_street_address)
          .with(2, hash_including(street: '1 Main St'), for_address_id: address.id)
      end
    end

    it 'keeps an existing review tag' do
      address.lgl_review!('also constituent 3')
      allow(client).to receive(:find).and_return(constituent(900_050))
      described_class.perform(address.id)
      expect(address.lgl_review_reason).to eq('also constituent 3')
    end

    context 'with a several-matches review left by a merge after the link' do
      let(:several) { Lgl::ConstituentReplicator::SEVERAL_MATCHES_REASON }

      before { allow(client).to receive(:find).with('900050').and_return(constituent(900_050)) }

      it 'clears the review when it names this constituent' do
        address.lgl_review!("LGL constituent 900050 #{several}")

        expect(described_class.perform(address.id, described_class::LINK_TRIGGER).action).to eq(:unchanged)
        expect(address.lgl_review_reason).to be_nil
        expect(address.lgl_id).to eq('900050')
      end

      it 'keeps the review when it names a different constituent' do
        address.lgl_review!("LGL constituent 900051 #{several}")
        described_class.perform(address.id, described_class::LINK_TRIGGER)
        expect(address.lgl_review_reason).to eq("LGL constituent 900051 #{several}")
      end

      it 'keeps an Also LGL constituent review' do
        allow(client).to receive(:find).with('1234').and_return(constituent(1234))
        address.lgl_review!('Also LGL constituent 1234')
        described_class.perform(address.id, described_class::LINK_TRIGGER)
        expect(address.lgl_review_reason).to eq('Also LGL constituent 1234')
      end
    end

    context 'with an Also LGL constituent review left for staff to merge in LGL' do
      before { allow(client).to receive(:find).with('900050').and_return(constituent(900_050)) }

      ['Also LGL constituent 900099', 'Also LGL constituent 900099: merge the two in LGL'].each do |reason|
        it "clears #{reason.inspect} once LGL confirms the other constituent is a 404" do
          allow(client).to receive(:find).with('900099').and_return(nil)
          address.lgl_review!(reason)

          expect(described_class.perform(address.id, described_class::LINK_TRIGGER).action).to eq(:unchanged)

          expect(address.lgl_review_reason).to be_nil
          expect(address.lgl_id).to eq('900050')
          expect(client).to have_received(:find).with('900099').once
        end
      end

      it 'keeps the review while the other constituent still exists' do
        allow(client).to receive(:find).with('900099').and_return(constituent(900_099))
        address.lgl_review!('Also LGL constituent 900099: merge the two in LGL')

        described_class.perform(address.id, described_class::LINK_TRIGGER)

        expect(address.lgl_review_reason).to eq('Also LGL constituent 900099: merge the two in LGL')
        expect(address.lgl_id).to eq('900050')
      end

      it 'makes no extra lookup when the review names the tagged constituent itself' do
        address.lgl_review!('Also LGL constituent 900050')

        described_class.perform(address.id, described_class::LINK_TRIGGER)

        expect(client).to have_received(:find).once
        expect(address.lgl_review_reason).to eq('Also LGL constituent 900050')
      end

      it 'makes no extra lookup without an Also LGL constituent review' do
        address.lgl_review!('LGL constituent 900099 is also linked to #5678')

        described_class.perform(address.id, described_class::LINK_TRIGGER)

        expect(client).to have_received(:find).once.with('900050')
        expect(address.lgl_review_reason).to eq('LGL constituent 900099 is also linked to #5678')
      end

      it 'makes no extra lookup when there is no review at all' do
        described_class.perform(address.id, described_class::LINK_TRIGGER)

        expect(client).to have_received(:find).once.with('900050')
      end
    end

    it 'replaces a dead link with a constituent found by external id' do
      allow(client).to receive(:find).and_return(nil)
      allow(client).to receive(:search_by_external_id).with(address.id).and_return([constituent(900_060)])

      described_class.perform(address.id, 'sweep')

      expect(address.lgl_id).to eq('900060')
    end

    context 'when the link is dead (LGL answers 404)' do
      before { allow(client).to receive(:find).with('900050').and_return(nil) }

      it 'replaces the tag with a constituent adopted by email' do
        allow(client).to receive(:search_by_email).and_return([constituent(900_080, external_id: '')])
        allow(client).to receive(:update)
        address.lgl_review!('old')
        expect(client).not_to receive(:create)

        expect(described_class.perform(address.id, 'sweep').action).to eq(:adopted)

        expect(address.lgl_id).to eq('900080')
        expect(address.lgl_review_reason).to be_nil
      end

      %w[sweep donation].each do |trigger|
        it "keeps the dead tag and flags review instead of creating on a #{trigger} trigger" do
          expect(client).not_to receive(:create)

          expect(described_class.perform(address.id, trigger).action).to eq(:review)

          expect(address.lgl_id).to eq('900050')
          expect(address.lgl_review_reason).to eq('LGL constituent 900050 no longer exists and no LGL constituent ' \
                                                  'matches; use Re-sync with LGL to create a new one')
        end
      end

      it 'clears the dead tag and creates a constituent on the manual trigger' do
        allow(client).to receive(:create).and_return({ 'id' => 900_123 })

        outcome = described_class.perform(address.id, described_class::MANUAL_TRIGGER)

        expect(outcome.action).to eq(:created)
        expect(client).to have_received(:create)
          .with(hash_including(external_constituent_id: address.id.to_s), for_address_id: address.id)
        expect(address.lgl_id).to eq('900123')
      end
    end
  end

  it 'adopts a constituent found by external id' do
    allow(client).to receive(:search_by_external_id).and_return([constituent(900_070)])
    address.lgl_review!('old')

    expect(described_class.perform(address.id).action).to eq(:adopted)
    expect(address.lgl_id).to eq('900070')
    expect(address.lgl_review_reason).to be_nil
  end

  it 'adopts by email, pushing the external id' do
    allow(client).to receive(:search_by_email).with(address.email).and_return([constituent(900_080, external_id: '')])
    allow(client).to receive(:update).and_return({ 'id' => 900_080 })

    described_class.perform(address.id)

    expect(client).to have_received(:update)
      .with(900_080, hash_including(external_constituent_id: address.id.to_s), for_address_id: address.id)
    expect(address.lgl_id).to eq('900080')
  end

  describe 'echo guard' do
    before do
      address.update_column(:updated_at, 1.hour.ago)
      allow(client).to receive(:search_by_email).with(address.email).and_return([constituent(900_080, external_id: '')])
      allow(Resque).to receive(:enqueue_in)
    end

    it 'touches the address after an external-id adopt so it is newer than LGL\'s bump' do
      allow(client).to receive(:update).and_return({ 'id' => 900_080 })

      expect { described_class.perform(address.id, 'link') }.to(change { address.reload.updated_at })

      expect(address.updated_at).to be_within(1.minute).of(Time.current)
    end

    it 'queues no edit push for that touch' do
      allow(client).to receive(:update).and_return({ 'id' => 900_080 })

      described_class.perform(address.id, 'link')

      expect(Resque).not_to have_received(:enqueue_in)
    end

    it 'leaves updated_at alone when the write was skipped read-only' do
      allow(client).to receive(:update).and_return(nil)

      expect { described_class.perform(address.id, 'link') }.not_to(change { address.reload.updated_at })
    end

    it 'leaves updated_at alone when nothing was written' do
      address.set_lgl_id!(900_090)
      allow(client).to receive(:find).with('900090').and_return(constituent(900_090))

      expect { described_class.perform(address.id) }.not_to(change { address.reload.updated_at })
    end
  end

  context 'on a link sync' do
    before { address.update_column(:updated_at, 1.hour.ago) }

    # Lgl::ConstituentReplicator tags the address before enqueuing this.
    context 'when the address is tagged' do
      before { address.set_lgl_id!(900_050) }

      it "sends only the external id with LGL's own names and emails" do
        lgl = constituent(900_050, external_id: '').merge('first_name' => 'Janie', 'phone_numbers' => [],
                                                          'street_addresses' => [])
        allow(client).to receive(:find).with('900050').and_return(lgl)
        allow(client).to receive(:update)
        expect(client).not_to receive(:create)

        expect(described_class.perform(address.id, described_class::LINK_TRIGGER).action).to eq(:updated)

        expect(client).to have_received(:update).once
        expect(client).to have_received(:update)
          .with(900_050, { first_name: 'Janie', last_name: 'Smith', external_constituent_id: address.id.to_s,
                           email_addresses: lgl['email_addresses'] }, for_address_id: address.id)
      end

      it 'skips without creating or flagging review when the constituent is gone (404)' do
        allow(client).to receive(:find).with('900050').and_return(nil)
        expect(client).not_to receive(:create)

        expect(described_class.perform(address.id, described_class::LINK_TRIGGER).action).to eq(:skipped)

        expect(address.lgl_id).to eq('900050')
        expect(address.lgl_review_reason).to be_nil
      end
    end

    it 'never creates a constituent when nothing matches: no write, no review tag, no touch' do
      expect(client).not_to receive(:create)
      allow(Rails.logger).to receive(:info)

      outcome = nil
      expect { outcome = described_class.perform(address.id, described_class::LINK_TRIGGER) }
        .not_to(change { address.reload.updated_at })

      expect([outcome.action, outcome.constituent_id]).to eq([:skipped, nil])
      expect(address.lgl_id).to be_nil
      expect(address.lgl_review_reason).to be_nil
      expect(Rails.logger).to have_received(:info)
        .with("[LGL] address ##{address.id}: link found no matching constituent; nothing created")
    end

    it 'still writes the review tag when several constituents match' do
      allow(client).to receive(:search_by_email)
        .and_return([constituent(900_081, external_id: ''), constituent(900_082, external_id: '')])

      expect(described_class.perform(address.id, described_class::LINK_TRIGGER).action).to eq(:review)
      expect(address.lgl_review_reason).to be_present
    end
  end

  it 'retries Lgl::RateLimited through resque-retry' do
    expect(described_class.retry_exception?(Lgl::RateLimited)).to be(true)
    expect(described_class.retry_limit).to be_positive
  end

  it 'tags an adopted constituent even when the update is skipped read-only' do
    allow(client).to receive(:search_by_email).and_return([constituent(900_080, external_id: '')])
    allow(client).to receive(:update).and_return(nil)

    described_class.perform(address.id)

    expect(address.lgl_id).to eq('900080')
  end

  context 'when the email is on a constituent linked to a same-name twin with another email' do
    let!(:twin) do
      FactoryBot.create(:address, first_name: 'Jane', last_name: 'Smith', full_name: 'Jane Smith',
                                  email: 'jane.other@example.com')
    end

    before do
      allow(client).to receive(:search_by_email).and_return([constituent(900_090, external_id: twin.id.to_s)])
      allow(Resque).to receive(:enqueue)
    end

    it 'merges into the lower id and enqueues a sync for the keeper, writing nothing to LGL now' do
      expect(client).not_to receive(:create)
      expect(client).not_to receive(:update)

      outcome = described_class.perform(address.id)

      expect(outcome.to_a).to eq([:merged, 900_090, "same person as address ##{twin.id} per LGL constituent 900090"])
      expect(Address.exists?(address.id)).to be(false)
      expect(Address.exists?(twin.id)).to be(true)
      expect(Resque).to have_received(:enqueue).with(described_class, twin.id, described_class::MERGE_TRIGGER)
    end

    it 'flags the address for review when LGL is read-only for the pair' do
      allow(Lgl).to receive_messages(read_only?: true, writable_address_ids: Set[address.id])

      expect(described_class.perform(address.id).action).to eq(:review)

      expect(address.lgl_review_reason)
        .to eq("Same person as ##{twin.id} in LGL; merge skipped because LGL is read-only for these addresses")
      expect(Address.exists?(twin.id)).to be(true)
      expect(Resque).not_to have_received(:enqueue)
    end

    it 'flags the address for review when an order is in flight' do
      allow(ConsolidateDuplicateAddresses).to receive(:in_flight?).and_return(true)
      expect(client).not_to receive(:create)

      expect(described_class.perform(address.id).action).to eq(:review)

      expect(address.lgl_review_reason)
        .to eq("Same person as ##{twin.id} in LGL; merge skipped while an order is in progress")
      expect(Address.exists?(twin.id)).to be(true)
      expect(Resque).not_to have_received(:enqueue)
    end
  end

  it 'flags the address for review when several constituents match' do
    allow(client).to receive(:search_by_email).and_return([constituent(900_001, external_id: ''),
                                                           constituent(900_002, external_id: '')])
    expect(client).not_to receive(:create)

    described_class.perform(address.id)

    expect(address.lgl_review_reason).to eq('LGL constituents 900001 and 900002 share this email')
    expect(address.lgl_id).to be_nil
  end

  it 'flags the address for review naming every constituent that carries its id as external id' do
    allow(client).to receive(:search_by_external_id).and_return([constituent(900_012), constituent(900_003),
                                                                 constituent(900_011)])
    expect(client).not_to receive(:create)

    described_class.perform(address.id)

    expect(address.lgl_review_reason)
      .to eq("LGL constituents 900003, 900011 and 900012 carry external id #{address.id}")
    expect(address.lgl_id).to be_nil
  end

  it 'creates a constituent for a never-linked address and tags it from the response' do
    allow(client).to receive(:create).and_return({ 'id' => 900_123 })

    described_class.perform(address.id, 'donation')

    expect(client).to have_received(:create)
      .with(hash_including(external_constituent_id: address.id.to_s, last_name: 'Smith'), for_address_id: address.id)
    expect(address.lgl_id).to eq('900123')
  end

  it 'writes no tag when the create is skipped read-only' do
    allow(client).to receive(:create).and_return(nil)

    expect(described_class.perform(address.id).action).to eq(:create_skipped)
    expect(address.lgl_id).to be_nil
  end

  it 'propagates LGL errors so Resque retries' do
    allow(client).to receive(:search_by_external_id).and_raise(Lgl::Error.new(status: 500))

    expect { described_class.perform(address.id) }.to raise_error(Lgl::Error)
  end

  # Live case: #359049 carried LGL ID 979634, merged away in LGL into 979629,
  # which #359050 was tagged with. The merge kept #359049 and flagged it
  # "Also LGL constituent 979634: merge the two in LGL" for a dead constituent.
  context 'when a dead link resolves to a merge with the survivor\'s twin' do
    let!(:dead) do
      FactoryBot.create(:address, first_name: 'Jane', last_name: 'Smith', full_name: 'Jane Smith',
                                  email: 'jane@example.com').tap { |a| a.set_lgl_id!(979_634) }
    end
    let!(:survivor) do
      FactoryBot.create(:address, first_name: 'Jane', last_name: 'Smith', full_name: 'Jane Smith',
                                  email: 'jane.other@example.com').tap { |a| a.set_lgl_id!(979_629) }
    end

    before do
      allow(client).to receive(:find).with('979634').and_return(nil)
      lgl = { 'id' => 979_629, 'first_name' => 'Jane', 'last_name' => 'Smith',
              'external_constituent_id' => survivor.id.to_s,
              'email_addresses' => [{ 'id' => 1, 'address' => dead.email, 'is_preferred' => true }] }
      allow(client).to receive(:search_by_email).and_return([lgl])
      allow(Resque).to receive(:enqueue)
    end

    it 'merges without flagging the dead id for review and keeps the survivor id' do
      expect(dead.id).to be < survivor.id

      outcome = described_class.perform(dead.id, 'sweep')

      expect(outcome.action).to eq(:merged)
      expect(Address.exists?(survivor.id)).to be(false)
      keeper = Address.find(dead.id)
      expect(keeper.lgl_id).to eq('979629')
      expect(keeper.lgl_review_reason).to be_nil
      expect(Resque).to have_received(:enqueue).with(described_class, dead.id, described_class::MERGE_TRIGGER)
    end

    it 'keeps the dead tag when the merge is skipped' do
      allow(ConsolidateDuplicateAddresses).to receive(:in_flight?).and_return(true)

      expect(described_class.perform(dead.id, 'sweep').action).to eq(:review)

      expect(dead.lgl_id).to eq('979634')
      expect(Address.exists?(survivor.id)).to be(true)
    end
  end

  describe 'gift replication on a fresh link' do
    before { allow(Resque).to receive(:enqueue) }

    def processed_donation(theater: house)
      FactoryBot.create(:donation_order_for_one_thousand_dollars, address: address, theater: theater)
                .tap { |o| o.update_column(:status, Order::PROCESSED) }
    end

    context 'once a campaign is chosen' do
      before { LglSetting.store_campaign(1, 'x') }

      it 'queues replication of the address\'s donations after adopting a constituent' do
        order = processed_donation
        allow(client).to receive(:search_by_external_id).and_return([constituent(900_070)])

        expect(described_class.perform(address.id, 'donation').action).to eq(:adopted)

        expect(Resque).to have_received(:enqueue).with(LglReplicateDonationJob, order.id)
      end

      it 'queues replication of the address\'s donations after creating a constituent' do
        order = processed_donation
        allow(client).to receive(:create).and_return({ 'id' => 900_123 })

        expect(described_class.perform(address.id, 'donation').action).to eq(:created)

        expect(Resque).to have_received(:enqueue).with(LglReplicateDonationJob, order.id)
      end

      it 'skips donations from before go-live, already replicated, or for another theater' do
        processed_donation.update_column(:created_at, LglSetting.gifts_since - 1.minute)
        processed_donation.update_column(:lgl_gift_id, 7001)
        processed_donation(theater: FactoryBot.create(:theater))
        allow(client).to receive(:search_by_external_id).and_return([constituent(900_070)])

        described_class.perform(address.id, 'donation')

        expect(Resque).not_to have_received(:enqueue).with(LglReplicateDonationJob, anything)
      end
    end

    it 'queues nothing before a campaign is chosen' do
      processed_donation
      allow(client).to receive(:search_by_external_id).and_return([constituent(900_070)])

      described_class.perform(address.id, 'donation')

      expect(Resque).not_to have_received(:enqueue).with(LglReplicateDonationJob, anything)
    end
  end

  describe 'gift history refresh' do
    it 'refreshes after adopting a constituent, with the same client' do
      allow(client).to receive(:search_by_external_id).and_return([constituent(900_070)])

      expect(described_class.perform(address.id, 'donation').action).to eq(:adopted)

      expect(Lgl::GiftHistoryRefresh).to have_received(:refresh).once.with(address, client: client)
    end

    it 'refreshes after creating a constituent' do
      allow(client).to receive(:create).and_return({ 'id' => 900_123 })

      expect(described_class.perform(address.id, 'donation').action).to eq(:created)

      expect(Lgl::GiftHistoryRefresh).to have_received(:refresh).once.with(address, client: client)
    end

    context 'when tagged' do
      before do
        address.set_lgl_id!(900_050)
        allow(client).to receive(:find).with('900050').and_return(constituent(900_050))
      end

      it 'refreshes on a manual Re-sync' do
        expect(described_class.perform(address.id, described_class::MANUAL_TRIGGER).action).to eq(:unchanged)

        expect(Lgl::GiftHistoryRefresh).to have_received(:refresh).once.with(address, client: client)
      end

      [described_class::LINK_TRIGGER, described_class::EDIT_TRIGGER, 'poll', 'sweep', 'donation'].each do |trigger|
        it "does not refresh on a #{trigger} sync" do
          described_class.perform(address.id, trigger)

          expect(Lgl::GiftHistoryRefresh).not_to have_received(:refresh)
        end
      end

      it 'logs a gift history error without failing the Re-sync' do
        allow(Lgl::GiftHistoryRefresh).to receive(:refresh).and_raise(Lgl::Error, 'LGL 500')
        allow(Rails.logger).to receive(:error)

        expect(described_class.perform(address.id, described_class::MANUAL_TRIGGER).action).to eq(:unchanged)

        expect(Rails.logger).to have_received(:error).with(a_string_including('gift history refresh failed', 'LGL 500'))
        expect(address.lgl_id).to eq('900050')
      end
    end

    it 'keeps the new link when the refresh after an adopt fails' do
      allow(client).to receive(:search_by_external_id).and_return([constituent(900_070)])
      allow(Lgl::GiftHistoryRefresh).to receive(:refresh).and_raise(Lgl::Error, 'LGL 500')

      expect(described_class.perform(address.id).action).to eq(:adopted)

      expect(address.lgl_id).to eq('900070')
    end
  end
end
