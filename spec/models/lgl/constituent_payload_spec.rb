# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::ConstituentPayload do
  let(:address) do
    FactoryBot.build_stubbed(:address, id: 42, first_name: 'Jane', last_name: 'Smith', full_name: 'Jane Smith',
                                       email: 'jane@example.com', line1: '1 Main St', line2: 'Apt 2',
                                       city: 'Chicago', state: 'IL', zipcode: '60601', phone: '773-555-0100')
  end

  describe '.for_create' do
    it 'sends names, external id, email, street and phone as preferred entries' do
      expect(described_class.for_create(address)).to eq(
        first_name: 'Jane', last_name: 'Smith', external_constituent_id: '42',
        email_addresses: [{ address: 'jane@example.com', is_preferred: true }],
        street_addresses: [{ street: "1 Main St\nApt 2", city: 'Chicago', state: 'IL', postal_code: '60601',
                             is_preferred: true }],
        phone_numbers: [{ number: '773-555-0100', is_preferred: true }]
      )
    end

    it 'omits email, street and phone when blank' do
      address.assign_attributes(email: '', line1: '', phone: nil)
      expect(described_class.for_create(address).keys).to eq(%i[first_name last_name external_constituent_id])
    end

    it 'falls back to the full name pieces when first and last are blank' do
      address.assign_attributes(first_name: '', last_name: '', full_name: 'Pat Q Doe')
      expect(described_class.for_create(address)).to include(first_name: 'Pat Q', last_name: 'Doe')
    end

    it "uses '-' only when no name is available" do
      address.assign_attributes(first_name: '', last_name: '', full_name: '')
      expect(described_class.for_create(address)).to include(first_name: '-', last_name: '-')
    end
  end

  describe '.for_update' do
    let(:emails) { [{ 'id' => 9, 'address' => 'old@example.com', 'is_preferred' => true, 'email_type_id' => 1 }] }
    let(:constituent) do
      { 'id' => 5, 'first_name' => 'Jane', 'last_name' => 'Smith', 'external_constituent_id' => '42',
        'email_addresses' => emails,
        'street_addresses' => [{ 'id' => 11, 'street' => "1 Main St\nApt 2", 'city' => 'chicago', 'state' => 'IL',
                                 'postal_code' => '60601', 'is_preferred' => true }],
        'phone_numbers' => [{ 'id' => 12, 'number' => '(773) 555-0100', 'is_preferred' => true }] }
    end

    it 'returns nil when LGL already matches' do
      expect(described_class.for_update(address, constituent, push_contact: true)).to be_nil
    end

    it 'sends the external id and passes existing emails back untouched' do
      constituent['external_constituent_id'] = ''
      payload = described_class.for_update(address, constituent, push_contact: true)
      expect(payload).to eq(first_name: 'Jane', last_name: 'Smith', external_constituent_id: '42',
                            email_addresses: emails)
    end

    it 'updates a changed name' do
      constituent['last_name'] = 'Smyth'
      expect(described_class.for_update(address, constituent, push_contact: true)).to include(last_name: 'Smith')
    end

    it 'keeps the LGL name when Stagemgr has none' do
      address.assign_attributes(first_name: '', last_name: '', full_name: '')
      expect(described_class.for_update(address, constituent, push_contact: true)).to be_nil
    end

    it "updates LGL's preferred street entry in place when it differs" do
      address.line1 = '2 Oak Ave'
      payload = described_class.for_update(address, constituent, push_contact: true)
      expect(payload[:street_addresses]).to eq([{ id: 11, street: "2 Oak Ave\nApt 2", city: 'Chicago', state: 'IL',
                                                  postal_code: '60601', is_preferred: true }])
      expect(payload).not_to have_key(:phone_numbers)
      expect(payload[:email_addresses]).to eq(emails)
    end

    it 'adds a new preferred phone when LGL has none' do
      constituent['phone_numbers'] = []
      payload = described_class.for_update(address, constituent, push_contact: true)
      expect(payload[:phone_numbers]).to eq([{ number: '773-555-0100', is_preferred: true }])
      expect(payload).not_to have_key(:street_addresses)
    end

    it 'updates a different phone number by id' do
      address.phone = '312-555-0199'
      payload = described_class.for_update(address, constituent, push_contact: true)
      expect(payload[:phone_numbers]).to eq([{ id: 12, number: '312-555-0199', is_preferred: true }])
    end

    context 'without push_contact' do
      it 'sends nothing when only contact fields differ' do
        address.assign_attributes(first_name: 'Janet', line1: '2 Oak Ave', phone: '312-555-0199')
        expect(described_class.for_update(address, constituent, push_contact: false)).to be_nil
      end

      it "repoints the external id with LGL's own names and emails" do
        address.assign_attributes(first_name: 'Janet', line1: '2 Oak Ave')
        constituent.merge!('external_constituent_id' => '', 'first_name' => 'Jane ')
        expect(described_class.for_update(address, constituent, push_contact: false))
          .to eq(first_name: 'Jane', last_name: 'Smith', external_constituent_id: '42', email_addresses: emails)
      end
    end

    it 'never removes LGL street or phone when Stagemgr has none' do
      address.assign_attributes(line1: '', phone: '')
      expect(described_class.for_update(address, constituent, push_contact: true)).to be_nil
    end
  end
end
