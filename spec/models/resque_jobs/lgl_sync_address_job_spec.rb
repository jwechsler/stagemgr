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
  end

  it 'does nothing when LGL is disabled' do
    allow(Lgl).to receive(:enabled?).and_return(false)
    expect(described_class.perform(address.id)).to be_nil
  end

  it 'does nothing for a placeholder address' do
    address.update_column(:placeholder, true)
    expect(described_class.perform(address.id)).to be_nil
  end

  it 'uses one lock per address whatever the reason' do
    expect(described_class.redis_lock_key(5, 'donation')).to eq(described_class.redis_lock_key(5, 'manual'))
  end

  context 'when tagged' do
    before { address.set_lgl_id!(50) }

    it 'makes no write when LGL already matches' do
      allow(client).to receive(:find).with('50').and_return(constituent(50))
      expect(client).not_to receive(:update)

      expect(described_class.perform(address.id).action).to eq(:unchanged)
    end

    it 'updates LGL when the external id differs' do
      allow(client).to receive(:find).and_return(constituent(50, external_id: ''))
      allow(client).to receive(:update)

      described_class.perform(address.id)

      expect(client).to have_received(:update)
        .with(50, hash_including(external_constituent_id: address.id.to_s), for_address_id: address.id)
    end

    it 'sends nothing on a donation sync when only the street differs' do
      allow(client).to receive(:find).and_return(constituent(50).merge('street_addresses' => []))
      expect(client).not_to receive(:update)

      described_class.perform(address.id, 'donation')
    end

    it "sends only the external id with LGL's own names and emails on a donation sync" do
      lgl = constituent(50, external_id: '').merge('first_name' => 'Janie', 'street_addresses' => [])
      allow(client).to receive(:find).and_return(lgl)
      allow(client).to receive(:update)

      described_class.perform(address.id, 'donation')

      expect(client).to have_received(:update)
        .with(50, { first_name: 'Janie', last_name: 'Smith', external_constituent_id: address.id.to_s,
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
        lgl = constituent(50, external_id: '')
        lgl['street_addresses'] = [other_street, lgl['street_addresses'].first.merge('street' => '8 Old Rd')]
        allow(client).to receive(:find).and_return(lgl)

        described_class.perform(address.id, described_class::EDIT_TRIGGER)

        expect(client).to have_received(:update_street_address)
          .with(2, { street: '1 Main St', city: 'Chicago', state: 'IL', postal_code: '60601' },
                for_address_id: address.id)
        expect(client).to have_received(:update)
          .with(50, satisfy { |body| !body.key?(:street_addresses) && !body.key?(:phone_numbers) },
                for_address_id: address.id)
        expect(client).not_to have_received(:add_street_address)
      end

      it 'adds a preferred Home street when LGL has no preferred entry' do
        allow(client).to receive(:find).and_return(constituent(50).merge('street_addresses' => [other_street]))

        expect(described_class.perform(address.id, described_class::EDIT_TRIGGER).action).to eq(:updated)

        expect(client).to have_received(:add_street_address)
          .with(50, hash_including(street: '1 Main St', street_address_type_id: 1, is_preferred: true),
                for_address_id: address.id)
        expect(client).not_to have_received(:update)
        expect(client).not_to have_received(:update_street_address)
      end

      it "logs LGL's preferred street and phone before the first write" do
        address.update!(phone: '773-555-0100')
        lgl = constituent(50)
        lgl['street_addresses'].first['street'] = '8 Old Rd'
        allow(client).to receive(:find).and_return(lgl)

        described_class.perform(address.id, described_class::EDIT_TRIGGER)

        expect(Rails.logger).to have_received(:info)
          .with("[LGL] address ##{address.id}: before edit, constituent 50 " \
                "preferred street=#{lgl['street_addresses'].first.to_json} phone=none").ordered
        expect(client).to have_received(:update_street_address).ordered
        expect(client).to have_received(:add_phone_number)
          .with(50, { number: '773-555-0100', phone_number_type_id: 1, is_preferred: true },
                for_address_id: address.id)
      end

      it 'writes and logs nothing when LGL already matches' do
        allow(client).to receive(:find).and_return(constituent(50))

        expect(described_class.perform(address.id, described_class::EDIT_TRIGGER).action).to eq(:unchanged)
        expect(client).not_to have_received(:update_street_address)
        expect(Rails.logger).not_to have_received(:info).with(/before edit/)
      end
    end

    it 'never touches street or phone entries on a non-edit sync' do
      address.update!(phone: '773-555-0100')
      lgl = constituent(50, external_id: '').merge('street_addresses' => [], 'phone_numbers' => [])
      allow(client).to receive(:find).and_return(lgl)
      allow(client).to receive(:update)

      %w[donation manual poll sweep].each { |reason| described_class.perform(address.id, reason) }

      expect(client).to have_received(:update).exactly(4).times
    end

    it 'keeps an existing review tag' do
      address.lgl_review!('also constituent 3')
      allow(client).to receive(:find).and_return(constituent(50))
      described_class.perform(address.id)
      expect(address.lgl_review_reason).to eq('also constituent 3')
    end

    it 'drops the tag and falls through when LGL answers 404' do
      allow(client).to receive(:find).and_return(nil)
      allow(client).to receive(:search_by_external_id).with(address.id).and_return([constituent(60)])

      described_class.perform(address.id)

      expect(address.lgl_id).to eq('60')
    end
  end

  it 'adopts a constituent found by external id' do
    allow(client).to receive(:search_by_external_id).and_return([constituent(70)])
    address.lgl_review!('old')

    expect(described_class.perform(address.id).action).to eq(:adopted)
    expect(address.lgl_id).to eq('70')
    expect(address.lgl_review_reason).to be_nil
  end

  it 'adopts by email, pushing the external id' do
    allow(client).to receive(:search_by_email).with(address.email).and_return([constituent(80, external_id: '')])
    allow(client).to receive(:update).and_return({ 'id' => 80 })

    described_class.perform(address.id)

    expect(client).to have_received(:update)
      .with(80, hash_including(external_constituent_id: address.id.to_s), for_address_id: address.id)
    expect(address.lgl_id).to eq('80')
  end

  it 'tags an adopted constituent even when the update is skipped read-only' do
    allow(client).to receive(:search_by_email).and_return([constituent(80, external_id: '')])
    allow(client).to receive(:update).and_return(nil)

    described_class.perform(address.id)

    expect(address.lgl_id).to eq('80')
  end

  it 'defers to duplicate consolidation without writing anything' do
    twin = FactoryBot.create(:address, first_name: 'Jane', last_name: 'Smith', full_name: 'Jane Smith',
                                       email: address.email)
    allow(client).to receive(:search_by_email).and_return([constituent(90, external_id: twin.id.to_s)])
    expect(client).not_to receive(:create)

    expect(described_class.perform(address.id).action).to eq(:deferred)
    expect(address.lgl_id).to be_nil
    expect(address.lgl_review_reason).to be_nil
  end

  it 'flags the address for review when several constituents match' do
    allow(client).to receive(:search_by_email).and_return([constituent(1, external_id: ''),
                                                           constituent(2, external_id: '')])
    expect(client).not_to receive(:create)

    described_class.perform(address.id)

    expect(address.lgl_review_reason).to eq('2 LGL constituents share this email')
    expect(address.lgl_id).to be_nil
  end

  it 'creates a constituent and tags the address from the response' do
    allow(client).to receive(:create).and_return({ 'id' => 123 })

    described_class.perform(address.id, 'donation')

    expect(client).to have_received(:create)
      .with(hash_including(external_constituent_id: address.id.to_s, last_name: 'Smith'), for_address_id: address.id)
    expect(address.lgl_id).to eq('123')
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
end
