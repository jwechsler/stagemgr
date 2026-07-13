require 'rails_helper'

RSpec.describe RemoveUnusedAddresses do
  def create_address(age: 2.days)
    address = FactoryBot.create(:address)
    address.update_column(:updated_at, age.ago)
    address
  end

  def watermark_time
    JobMetadata.last_run(described_class::WATERMARK)
  end

  it 'destroys stale addresses with no orders and no tags, then advances the watermark' do
    unused = create_address

    expect(described_class.perform).to eq(1)

    expect(Address.exists?(unused.id)).to be false
    expect(watermark_time).to be_within(1.minute).of(described_class::MINIMUM_AGE.ago)
  end

  it 'preserves addresses attached to an order' do
    order = FactoryBot.create(:ticket_order)
    order.address.update_column(:updated_at, 2.days.ago)

    described_class.perform

    expect(Address.exists?(order.address_id)).to be true
  end

  it 'preserves addresses with tags' do
    tagged = create_address
    AddressTag.create!(address: tagged, tag_label: 'External ID', tag_value: '123')

    described_class.perform

    expect(Address.exists?(tagged.id)).to be true
  end

  it 'preserves addresses updated within the minimum age window' do
    fresh = create_address(age: 1.hour)

    expect(described_class.perform).to eq(0)

    expect(Address.exists?(fresh.id)).to be true
  end

  it 'skips addresses already examined by a previous run' do
    JobMetadata.create!(job_name: described_class::WATERMARK, last_run_at: 1.week.ago)
    previously_examined = create_address(age: 2.weeks)
    newly_stale = create_address(age: 2.days)

    expect(described_class.perform).to eq(1)

    expect(Address.exists?(previously_examined.id)).to be true
    expect(Address.exists?(newly_stale.id)).to be false
  end
end
