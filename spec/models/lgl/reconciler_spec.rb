# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::Reconciler do
  subject(:reconciler) { described_class.new(reason: 'poll') }

  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }

  def patron(name, email: nil)
    first, last = name.split
    attrs = { first_name: first, last_name: last, full_name: name }
    attrs[:email] = email if email
    FactoryBot.create(:address, attrs)
  end

  def constituent(id, external_id)
    { 'id' => id, 'external_constituent_id' => external_id.to_s }
  end

  before { allow(Resque).to receive(:enqueue) }

  context 'when the external id is a live address' do
    let(:address) { patron('Jane Smith') }

    it 'does nothing when that address alone is tagged with the constituent' do
      address.set_lgl_id!(50)

      expect(reconciler.apply(constituent(50, address.id))).to eq(:already_tagged)
      expect(Resque).not_to have_received(:enqueue)
    end

    it 'tags the address locally when nobody carries the constituent' do
      expect(reconciler.apply(constituent(50, address.id))).to eq(:tagged)

      expect(address.lgl_id).to eq('50')
      expect(Resque).not_to have_received(:enqueue)
    end

    it 'flags the address for review when it already names another constituent' do
      address.set_lgl_id!(40)

      expect(reconciler.apply(constituent(50, address.id))).to eq(:review)

      expect(address.lgl_id).to eq('40')
      expect(address.lgl_review_reason).to eq('Also LGL constituent 50')
    end
  end

  context 'when another address is tagged with the constituent' do
    it 'merges duplicates into the lower id when the external id is the higher one' do
      lower = patron('Jane Smith', email: 'one@example.com')
      higher = patron('Jane Smith', email: 'two@example.com')
      lower.set_lgl_id!(50)

      expect(reconciler.apply(constituent(50, higher.id))).to eq(:merged)

      expect(Address.exists?(higher.id)).to be(false)
      expect(lower.lgl_id).to eq('50')
      expect(Resque).to have_received(:enqueue).with(LglSyncAddressJob, lower.id, 'poll')
    end

    it 'merges duplicates into the lower id when the external id is the lower one' do
      lower = patron('Jane Smith')
      higher = patron('Janet Smythe', email: lower.email)
      higher.set_lgl_id!(50)

      expect(reconciler.apply(constituent(50, lower.id))).to eq(:merged)

      expect(Address.exists?(higher.id)).to be(false)
      expect(lower.reload.lgl_id).to eq('50')
      expect(Resque).to have_received(:enqueue).with(LglSyncAddressJob, lower.id, 'poll')
    end

    it 'flags both for review when they are not Stagemgr duplicates' do
      external = patron('Jane Smith')
      other = patron('Bob Jones')
      other.set_lgl_id!(50)

      expect(reconciler.apply(constituent(50, external.id))).to eq(:review)

      expect(Address.exists?(external.id) && Address.exists?(other.id)).to be(true)
      expect(external.lgl_review_reason).to eq("LGL constituent 50 is also linked to ##{other.id}")
      expect(other.lgl_review_reason).to eq("LGL constituent 50 is also linked to ##{external.id}")
      expect(Resque).not_to have_received(:enqueue)
    end

    it 'skips the merge this run when either address is in flight' do
      external = patron('Jane Smith')
      other = patron('Jane Smith')
      other.set_lgl_id!(50)
      allow(ConsolidateDuplicateAddresses).to receive(:in_flight?).and_return(true)

      expect(reconciler.apply(constituent(50, external.id))).to eq(:in_flight)

      expect(Address.exists?(external.id) && Address.exists?(other.id)).to be(true)
      expect(Resque).not_to have_received(:enqueue)
    end

    it 'flags both for review instead of merging when LGL is read-only for the pair' do
      external = patron('Jane Smith')
      other = patron('Jane Smith')
      other.set_lgl_id!(50)
      allow(Lgl).to receive_messages(read_only?: true, writable_address_ids: Set[external.id])

      expect(reconciler.apply(constituent(50, external.id))).to eq(:review)

      expect(Address.exists?(external.id) && Address.exists?(other.id)).to be(true)
      expect(Resque).not_to have_received(:enqueue)
    end
  end

  context 'when the external id is junk' do
    it 'enqueues a re-pointing sync when exactly one address is tagged' do
      address = patron('Jane Smith')
      address.set_lgl_id!(50)

      expect(reconciler.apply(constituent(50, 999_999_999))).to eq(:repointed)
      expect(Resque).to have_received(:enqueue).with(LglSyncAddressJob, address.id, 'poll')
    end

    it 'treats the constituent\'s own id as junk' do
      address = patron('Jane Smith')
      address.set_lgl_id!(50)

      expect(reconciler.apply(constituent(50, 50))).to eq(:repointed)
    end

    it 'treats a placeholder address as junk' do
      placeholder = patron('Jane Smith')
      placeholder.update_column(:placeholder, true)

      expect(reconciler.apply(constituent(50, placeholder.id))).to eq(:dead_external_id)
      expect(placeholder.lgl_id).to be_nil
    end

    it 'flags every tagged address when several carry the constituent' do
      first = patron('Jane Smith')
      second = patron('Bob Jones')
      [first, second].each { |address| address.set_lgl_id!(50) }

      expect(reconciler.apply(constituent(50, ''))).to eq(:review)

      expect([first, second].map(&:lgl_review_reason)).to all(include('constituent 50'))
      expect(Resque).not_to have_received(:enqueue)
    end

    it 'classifies an unlinked constituent by why its external id is junk' do
      expect(reconciler.apply(constituent(50, ''))).to eq(:blank_external_id)
      expect(reconciler.apply(constituent(50, 50))).to eq(:self_referencing)
      expect(reconciler.apply(constituent(50, 999_999_999))).to eq(:dead_external_id)
      expect(Resque).not_to have_received(:enqueue)
    end
  end

  context 'when local_only (backfill)' do
    subject(:reconciler) { described_class.new(reason: 'backfill', local_only: true) }

    it 'neither merges nor enqueues for duplicates' do
      lower = patron('Jane Smith')
      higher = patron('Jane Smith')
      lower.set_lgl_id!(50)

      expect(reconciler.apply(constituent(50, higher.id))).to eq(:deferred)
      expect(Address.exists?(higher.id)).to be(true)
      expect(Resque).not_to have_received(:enqueue)
    end

    it 'does not enqueue a re-pointing sync for a junk external id' do
      patron('Jane Smith').set_lgl_id!(50)

      expect(reconciler.apply(constituent(50, 999_999_999))).to eq(:dead_external_id)
      expect(Resque).not_to have_received(:enqueue)
    end
  end

  describe 'errors' do
    it 'logs and counts an unexpected error instead of raising' do
      allow(Address).to receive(:find_by).and_raise(ActiveRecord::StatementInvalid, 'boom')

      expect(reconciler.apply(constituent(50, 1))).to eq(:error)
    end

    it 're-raises LGL errors so the job fails' do
      allow(Address).to receive(:find_by).and_raise(Lgl::RateLimited.new(status: 429))

      expect { reconciler.apply(constituent(50, 1)) }.to raise_error(Lgl::RateLimited)
    end
  end
end
