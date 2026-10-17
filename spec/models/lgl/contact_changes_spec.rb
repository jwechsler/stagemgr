# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::ContactChanges do
  subject(:changes) { described_class.new(address, constituent) }

  let(:address) do
    FactoryBot.build_stubbed(:address, id: 42, line1: '1 Main St', line2: 'Apt 2', city: 'Chicago', state: 'IL',
                                       zipcode: '60601', phone: '773-555-0100')
  end
  let(:other_street) do
    { 'id' => 10, 'street' => '9 Work Rd', 'city' => 'Evanston', 'state' => 'IL', 'postal_code' => '60201',
      'is_preferred' => false }
  end
  let(:preferred_street) do
    { 'id' => 11, 'street' => "1 Main St\nApt 2", 'city' => 'Chicago', 'state' => 'IL', 'postal_code' => '60601',
      'is_preferred' => true }
  end
  let(:constituent) do
    { 'id' => 5,
      'street_addresses' => [other_street, preferred_street],
      'phone_numbers' => [{ 'id' => 20, 'number' => '312-000-0000', 'is_preferred' => false },
                          { 'id' => 21, 'number' => '(773) 555-0100', 'is_preferred' => true }] }
  end

  describe '#street' do
    it 'is nil when the preferred entry matches, ignoring spacing' do
      preferred_street['street'] = "1 Main  St \nApt 2"
      expect(changes.street).to be_nil
    end

    it 'updates the preferred entry when only capitalization differs' do
      preferred_street['street'] = "1 MAin St\nApt 2"
      expect(changes.street.to_h).to eq(action: :update, id: 11,
                                        attrs: { street: "1 Main St\nApt 2", city: 'Chicago', state: 'IL',
                                                 postal_code: '60601' })
    end

    it 'updates the preferred entry by id with only the four street fields' do
      address.line1 = '2 Oak Ave'
      expect(changes.street.to_h).to eq(action: :update, id: 11,
                                        attrs: { street: "2 Oak Ave\nApt 2", city: 'Chicago', state: 'IL',
                                                 postal_code: '60601' })
    end

    it 'adds a preferred Home entry when only non-preferred entries exist' do
      constituent['street_addresses'] = [other_street]
      expect(changes.street.to_h).to eq(action: :add, id: nil,
                                        attrs: { street: "1 Main St\nApt 2", city: 'Chicago', state: 'IL',
                                                 postal_code: '60601', street_address_type_id: 1,
                                                 is_preferred: true })
    end

    it 'never edits a first entry that is not preferred' do
      constituent['street_addresses'] = [preferred_street.merge('is_preferred' => false)]
      expect(changes.street.action).to eq(:add)
    end

    it 'is nil when Stagemgr has no street' do
      address.line1 = ''
      constituent['street_addresses'] = []
      expect(changes.street).to be_nil
    end
  end

  describe '#phone' do
    it 'is nil when the preferred number has the same digits' do
      expect(changes.phone).to be_nil
    end

    it 'updates the preferred number by id' do
      address.phone = '312-555-0199'
      expect(changes.phone.to_h).to eq(action: :update, id: 21, attrs: { number: '312-555-0199' })
    end

    it 'adds a preferred Home number when only non-preferred numbers exist' do
      constituent['phone_numbers'] = [{ 'id' => 20, 'number' => '773-555-0100', 'is_preferred' => false }]
      expect(changes.phone.to_h).to eq(action: :add, id: nil,
                                       attrs: { number: '773-555-0100', phone_number_type_id: 1,
                                                is_preferred: true })
    end

    it 'is nil when Stagemgr has no phone' do
      address.phone = nil
      constituent['phone_numbers'] = []
      expect(changes.phone).to be_nil
    end
  end

  it 'reports the preferred entries as LGL returned them' do
    expect(changes.preferred_street).to eq(preferred_street)
    expect(changes.preferred_phone['id']).to eq(21)
  end
end
