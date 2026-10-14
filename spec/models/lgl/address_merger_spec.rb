# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::AddressMerger do
  def patron(name, email:)
    first, last = name.split
    FactoryBot.create(:address, first_name: first, last_name: last, full_name: name, email: email)
  end

  let!(:lower) { patron('Jane Smith', email: 'jane@example.com') }
  let!(:higher) { patron('Jane Smith', email: 'jsmith@example.org') }

  it 'keeps the lower id when given the lower one first' do
    expect(described_class.merge_pair(lower, higher)).to eq([:merged, lower])
    expect(Address.exists?(higher.id)).to be(false)
  end

  it 'keeps the lower id when given the higher one first' do
    expect(described_class.merge_pair(higher, lower)).to eq([:merged, lower])
    expect(Address.exists?(higher.id)).to be(false)
  end

  it 'merges a different name with the same email' do
    other = patron('Janet Smythe', email: ' JANE@example.com ')
    expect(described_class.merge_pair(other, lower)).to eq([:merged, lower])
  end

  it 'skips the merge when either address is in flight' do
    allow(ConsolidateDuplicateAddresses).to receive(:in_flight?).with([lower, higher]).and_return(true)

    expect(described_class.merge_pair(lower, higher)).to eq([:in_flight, nil])
    expect(Address.exists?(lower.id) && Address.exists?(higher.id)).to be(true)
  end

  it 'refuses addresses with different names and emails' do
    other = patron('John Jones', email: 'john@example.com')

    expect(described_class.merge_pair(lower, other)).to eq([:not_duplicates, nil])
    expect(Address.exists?(lower.id) && Address.exists?(other.id)).to be(true)
  end
end
