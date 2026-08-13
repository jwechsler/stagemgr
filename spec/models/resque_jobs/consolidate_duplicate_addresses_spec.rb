require 'rails_helper'

RSpec.describe ConsolidateDuplicateAddresses, type: :model do
  include_context 'auto-fulfilling print service'

  def duplicate_pair(full_name:, email:)
    keeper = FactoryBot.create(:address, full_name: full_name, email: email)
    duplicate = FactoryBot.create(:address, full_name: full_name, email: email)
    [keeper, duplicate]
  end

  it 'merges strict duplicates into the oldest record and moves their orders' do
    keeper, duplicate = duplicate_pair(full_name: 'Dana Duplicate', email: 'dana@example.com')
    order = FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_cash, address: duplicate)

    merged = described_class.perform

    expect(merged).to be >= 1
    expect(Address.exists?(duplicate.id)).to be(false)
    expect(order.reload.address_id).to eq(keeper.id)
  end

  it 'is idempotent - a second run finds nothing to merge' do
    duplicate_pair(full_name: 'Dana Duplicate', email: 'dana@example.com')

    described_class.perform
    expect(described_class.perform).to eq(0)
  end

  it 'respects the group limit' do
    duplicate_pair(full_name: 'Alpha Person', email: 'alpha@example.com')
    duplicate_pair(full_name: 'Beta Person', email: 'beta@example.com')

    expect(described_class.perform(1)).to eq(1)
    expect(described_class.perform(1)).to eq(1) # second group on the next run
    expect(described_class.perform(1)).to eq(0)
  end

  it 'never touches placeholder or blank-email records' do
    FactoryBot.create(:address, full_name: 'No Email', email: '')
    FactoryBot.create(:address, full_name: 'No Email', email: '')
    ph1 = FactoryBot.create(:address, full_name: 'Place Holder', email: 'ph@example.com', placeholder: true)
    ph2 = FactoryBot.create(:address, full_name: 'Place Holder', email: 'ph@example.com', placeholder: true)

    expect(described_class.perform).to eq(0)
    expect(Address.exists?(ph1.id) && Address.exists?(ph2.id)).to be(true)
  end

  it 'skips a group referenced by an in-flight order' do
    _keeper, duplicate = duplicate_pair(full_name: 'Mid Checkout', email: 'mid@example.com')
    order = FactoryBot.create(:ticket_order, :for_a_single_ticket, address: duplicate)
    order.update_columns(status: Order::PROCESSING)

    expect(described_class.perform).to eq(0)
    expect(Address.exists?(duplicate.id)).to be(true)
  end

  it 'continues past a group that fails to merge' do
    _bad_keeper, bad_duplicate = duplicate_pair(full_name: 'Bad Group', email: 'bad@example.com')
    good_keeper, good_duplicate = duplicate_pair(full_name: 'Good Group', email: 'good@example.com')
    allow_any_instance_of(Address).to receive(:merge_and_purge).and_call_original
    allow_any_instance_of(Address).to receive(:merge_and_purge)
      .with(having_attributes(id: bad_duplicate.id))
      .and_raise(StandardError, 'boom')

    merged = described_class.perform

    expect(merged).to eq(1)
    expect(Address.exists?(good_duplicate.id)).to be(false)
    expect(good_keeper.reload).to be_present
  end
end
