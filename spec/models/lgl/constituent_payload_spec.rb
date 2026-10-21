# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::ConstituentPayload do
  let(:address) do
    FactoryBot.build_stubbed(:address, id: 42, first_name: 'Jane', middle_name: 'Q', last_name: 'Smith',
                                       full_name: 'Jane Q Smith',
                                       email: 'jane@example.com', line1: '1 Main St', line2: 'Apt 2',
                                       city: 'Chicago', state: 'IL', zipcode: '60601', phone: '773-555-0100')
  end

  describe '.for_create' do
    it 'sends names, external id, email, street and phone as preferred entries' do
      expect(described_class.for_create(address)).to eq(
        first_name: 'Jane', middle_name: 'Q', last_name: 'Smith', external_constituent_id: '42',
        email_addresses: [{ address: 'jane@example.com', is_preferred: true }],
        street_addresses: [{ street: "1 Main St\nApt 2", city: 'Chicago', state: 'IL', postal_code: '60601',
                             street_address_type_id: 1, is_preferred: true }],
        phone_numbers: [{ number: '773-555-0100', phone_number_type_id: 1, is_preferred: true }]
      )
    end

    it 'omits email, street and phone when blank' do
      address.assign_attributes(email: '', line1: '', phone: nil)
      expect(described_class.for_create(address).keys).to eq(%i[first_name middle_name last_name external_constituent_id])
    end

    it 'falls back to the full name pieces when first and last are blank' do
      address.assign_attributes(first_name: '', middle_name: '', last_name: '', full_name: 'Pat Q Doe')
      expect(described_class.for_create(address)).to include(first_name: 'Pat', middle_name: 'Q', last_name: 'Doe')
    end

    it 'never pairs a stored first name with a middle initial parsed from full_name' do
      address.assign_attributes(first_name: 'Pat Q', middle_name: nil, last_name: 'Doe', full_name: 'Pat Q Doe')
      expect(described_class.for_create(address)).to include(first_name: 'Pat Q', middle_name: '', last_name: 'Doe')
    end

    it "uses '-' only when no name is available" do
      address.assign_attributes(first_name: '', middle_name: '', last_name: '', full_name: '')
      expect(described_class.for_create(address)).to include(first_name: '-', middle_name: '', last_name: '-')
    end
  end

  describe '.for_update' do
    let(:emails) { [{ 'id' => 9, 'address' => 'old@example.com', 'is_preferred' => true, 'email_type_id' => 1 }] }
    let(:constituent) do
      { 'id' => 5, 'first_name' => 'Jane', 'middle_name' => 'Q', 'last_name' => 'Smith', 'external_constituent_id' => '42',
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
      expect(payload).to eq(first_name: 'Jane', middle_name: 'Q', last_name: 'Smith', external_constituent_id: '42',
                            email_addresses: emails)
    end

    it 'updates a changed name' do
      constituent['last_name'] = 'Smyth'
      expect(described_class.for_update(address, constituent, push_contact: true)).to include(last_name: 'Smith')
    end

    it 'updates a changed middle initial, including clearing one' do
      constituent['middle_name'] = 'R'
      expect(described_class.for_update(address, constituent, push_contact: true)).to include(middle_name: 'Q')

      address.assign_attributes(middle_name: '')
      expect(described_class.for_update(address, constituent, push_contact: true)).to include(middle_name: '')
    end

    it 'keeps the LGL name when Stagemgr has none' do
      address.assign_attributes(first_name: '', middle_name: '', last_name: '', full_name: '')
      expect(described_class.for_update(address, constituent, push_contact: true)).to be_nil
    end

    it 'never carries street or phone, even when they differ' do
      address.assign_attributes(line1: '2 Oak Ave', phone: '312-555-0199')
      constituent['street_addresses'] = []
      expect(described_class.for_update(address, constituent, push_contact: true)).to be_nil

      constituent['last_name'] = 'Smyth'
      payload = described_class.for_update(address, constituent, push_contact: true)
      expect(payload.keys).to eq(%i[first_name middle_name last_name external_constituent_id email_addresses])
    end

    context 'without push_contact' do
      it 'sends nothing when only contact fields differ' do
        address.assign_attributes(first_name: 'Janet', middle_name: '', line1: '2 Oak Ave', phone: '312-555-0199')
        expect(described_class.for_update(address, constituent, push_contact: false)).to be_nil
      end

      it "repoints the external id with LGL's own names and emails" do
        address.assign_attributes(first_name: 'Janet', middle_name: '', line1: '2 Oak Ave')
        constituent.merge!('external_constituent_id' => '', 'first_name' => 'Jane ')
        expect(described_class.for_update(address, constituent, push_contact: false))
          .to eq(first_name: 'Jane', middle_name: 'Q', last_name: 'Smith', external_constituent_id: '42',
                 email_addresses: emails)
      end
    end
  end
end
