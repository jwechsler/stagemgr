# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::ContactPull do
  subject(:pull) { described_class.new(address, constituent) }

  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:stamp) { Time.zone.parse('2026-10-01T12:00:00Z') }
  let(:newer) { '2026-10-02T12:00:00Z' }
  let(:older) { '2026-09-30T12:00:00Z' }
  let(:address) do
    FactoryBot.create(:address, full_name: 'Jane Smith', email: 'jane@example.com', line1: '1 Main St', line2: '',
                                city: 'Chicago', state: 'IL', zipcode: '60601', phone: '773-555-0100')
  end
  let(:street) do
    { 'id' => 11, 'street' => '1 Main St', 'city' => 'Chicago', 'state' => 'IL', 'postal_code' => '60601',
      'is_preferred' => true, 'updated_at' => newer }
  end
  let(:phone) { { 'id' => 21, 'number' => '(773) 555-0100', 'is_preferred' => true, 'updated_at' => newer } }
  let(:constituent) do
    { 'id' => 979_629, 'external_constituent_id' => address.id.to_s, 'updated_at' => newer,
      'first_name' => 'Jane', 'last_name' => 'Smith',
      'email_addresses' => [{ 'id' => 1, 'address' => 'other@example.com', 'is_preferred' => true }],
      'street_addresses' => [street], 'phone_numbers' => [phone] }
  end

  before do
    allow(Lgl).to receive(:enabled?).and_return(true)
    allow(Resque).to receive(:enqueue_in)
    address.set_lgl_id!(979_629)
    address.update_column(:updated_at, stamp)
    address.reload
  end

  it 'is a no-op when LGL already matches' do
    expect(pull.apply!).to eq([])
    expect(address.reload.updated_at).to eq(stamp)
  end

  it 'pulls a newer preferred street, splitting line2 at the first newline' do
    street.merge!('street' => "6924 N Sheridan Rd\nApt 3\nRear", 'postal_code' => '60657-3205')

    expect(pull.apply!).to eq([:street])

    address.reload
    expect([address.line1, address.line2, address.zipcode]).to eq(['6924 N Sheridan Rd', "Apt 3\nRear", '60657-3205'])
  end

  it 'leaves the street alone when the preferred entry is older than the address' do
    street.merge!('street' => '6924 N Sheridan Rd', 'updated_at' => older)
    expect(pull.apply!).to eq([])
    expect(address.reload.line1).to eq('1 Main St')
  end

  it 'never blanks the street or phone when LGL has no preferred entry' do
    constituent['street_addresses'] = [street.merge('is_preferred' => false, 'street' => '')]
    constituent['phone_numbers'] = []
    expect(pull.apply!).to eq([])
    expect(address.reload.attributes.values_at('line1', 'phone')).to eq(['1 Main St', '773-555-0100'])
  end

  it 'pulls a newer preferred phone' do
    phone['number'] = '312-555-0199'
    expect(pull.apply!).to eq([:phone])
    expect(address.reload.phone).to eq('312-555-0199')
  end

  it 'treats a phone differing only in formatting as equal' do
    phone['number'] = '773.555.0100'
    expect(pull.apply!).to eq([])
  end

  it 'leaves the phone alone when the entry is older' do
    phone.merge!('number' => '312-555-0199', 'updated_at' => older)
    expect(pull.apply!).to eq([])
  end

  context 'when LGL is newer only within CLOCK_SKEW_ALLOWANCE' do
    let(:within_slack) { (stamp + described_class::CLOCK_SKEW_ALLOWANCE - 1.second).utc.iso8601 }

    it 'does not pull (an echo of our own write, or clock skew)' do
      constituent.merge!('first_name' => 'Janet', 'updated_at' => within_slack)
      phone.merge!('number' => '312-555-0199', 'updated_at' => within_slack)

      expect(pull.apply!).to eq([])
      expect(address.reload.phone).to eq('773-555-0100')
    end

    it 'still pulls once LGL is clearly newer' do
      clearly_newer = (stamp + described_class::CLOCK_SKEW_ALLOWANCE + 1.minute).utc.iso8601
      phone.merge!('number' => '312-555-0199', 'updated_at' => clearly_newer)

      expect(pull.apply!).to eq([:phone])
    end
  end

  it 'pulls a newer name into full_name and lets regularize! split it' do
    constituent['first_name'] = 'Janet'
    expect(pull.apply!).to eq([:name])
    address.reload
    expect([address.full_name, address.first_name, address.last_name]).to eq(['Janet Smith', 'Janet', 'Smith'])
  end

  it 'leaves the name alone when the constituent is older' do
    constituent.merge!('first_name' => 'Janet', 'updated_at' => older)
    expect(pull.apply!).to eq([])
  end

  it 'skips the name when LGL has neither first nor last name' do
    constituent.merge!('first_name' => '', 'last_name' => nil)
    expect(pull.apply!).to eq([])
    expect(address.reload.full_name).to eq('Jane Smith')
  end

  it 'never touches email' do
    phone['number'] = '312-555-0199'
    pull.apply!
    expect(address.reload.email).to eq('jane@example.com')
  end

  it 'does not queue an edit push for the values it pulled' do
    phone['number'] = '312-555-0199'
    pull.apply!
    expect(Resque).not_to have_received(:enqueue_in)
    expect(address.lgl_pull_in_progress).to be(false)
  end

  it 'logs the pulled groups with the previous values' do
    allow(Rails.logger).to receive(:info)
    phone['number'] = '312-555-0199'
    pull.apply!
    expect(Rails.logger).to have_received(:info)
      .with(a_string_including("address ##{address.id}: pulled phone from constituent 979629", '773-555-0100'))
  end

  context 'when the constituent does not name this address' do
    before { phone['number'] = '312-555-0199' }

    ['', 'junk', '999999999'].each do |external_id|
      it "never pulls with external id #{external_id.inspect}" do
        constituent['external_constituent_id'] = external_id
        expect(pull.apply!).to eq([])
        expect(address.reload.phone).to eq('773-555-0100')
      end
    end

    it 'never pulls when the address is tagged with another constituent' do
      address.set_lgl_id!(900_001)
      expect(pull.apply!).to eq([])
    end
  end

  it 'does nothing when LGL is disabled' do
    allow(Lgl).to receive(:enabled?).and_return(false)
    phone['number'] = '312-555-0199'
    expect(pull.apply!).to eq([])
  end
end
