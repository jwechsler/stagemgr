# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LglLinkable do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:other_theater) { FactoryBot.create(:theater, theater_class: Theater::RESIDENT) }
  let(:address) { FactoryBot.create(:address) }

  def lgl_rows(label = AddressTag::LGL_ID)
    AddressTag.where(address_id: address.id, tag_label: label)
  end

  it 'reads nil when untagged' do
    expect(address.lgl_id).to be_nil
    expect(address.lgl_review_reason).to be_nil
  end

  it 'writes the LGL ID on the default theater' do
    address.set_lgl_id!(123)
    expect(address.lgl_id).to eq('123')
    expect(lgl_rows.pluck(:theater_id)).to eq([house.id])
  end

  it 'replaces the value instead of adding a row' do
    address.set_lgl_id!(1)
    address.set_lgl_id!(2)
    expect(lgl_rows.pluck(:tag_value)).to eq(['2'])
  end

  it 'collapses pre-existing duplicate rows' do
    2.times { |n| AddressTag.create!(address: address, theater: house, tag_label: AddressTag::LGL_ID, tag_value: n) }
    address.set_lgl_id!(9)
    expect(lgl_rows.pluck(:tag_value)).to eq(['9'])
  end

  it "ignores another theater's tag with the same label" do
    AddressTag.create!(address: address, theater: other_theater, tag_label: AddressTag::LGL_ID, tag_value: '77')
    expect(address.lgl_id).to be_nil
    address.set_lgl_id!(5)
    expect(lgl_rows.count).to eq(2)
  end

  it 'never saves the address row' do
    address.update_column(:updated_at, 1.day.ago)
    stamp = address.reload.updated_at
    address.set_lgl_id!(1)
    address.lgl_review!('check')
    address.clear_lgl_review!
    address.clear_lgl_id!
    expect(address.reload.updated_at).to eq(stamp)
  end

  it 'clears the LGL ID' do
    address.set_lgl_id!(1)
    address.clear_lgl_id!
    expect(address.lgl_id).to be_nil
    expect(lgl_rows).to be_empty
  end

  it 'writes and clears the review reason' do
    address.lgl_review!('two constituents')
    expect(address.lgl_review_reason).to eq('two constituents')
    address.clear_lgl_review!
    expect(address.lgl_review_reason).to be_nil
  end

  describe 'Also LGL constituent reviews' do
    it 'builds both wordings' do
      expect(described_class.also_constituent_reason(1234)).to eq('Also LGL constituent 1234')
      expect(described_class.also_constituent_reason(1234, merge_in_lgl: true))
        .to eq('Also LGL constituent 1234: merge the two in LGL')
    end

    it 'parses the constituent id from both wordings' do
      expect(described_class.also_constituent_id('Also LGL constituent 1234')).to eq('1234')
      expect(described_class.also_constituent_id('Also LGL constituent 1234: merge the two in LGL')).to eq('1234')
    end

    it 'round-trips the id through the built reason' do
      reason = described_class.also_constituent_reason(987_654, merge_in_lgl: true)
      expect(described_class.also_constituent_id(reason)).to eq('987654')
    end

    it 'returns nil for any other reason, a blank or nil' do
      ['LGL constituent 1234 matches several customers by email and last name',
       'LGL constituent 1234 is also linked to #5678',
       'also LGL constituent 1234',
       'Also LGL constituent',
       'Also LGL constituent abc',
       'Also LGL constituent 12a',
       '', nil].each do |reason|
        expect(described_class.also_constituent_id(reason)).to be_nil, "expected nil for #{reason.inspect}"
      end
    end

    it 'reads the other constituent id from the address review' do
      expect(address.lgl_review_other_constituent_id).to be_nil
      address.lgl_review!('Also LGL constituent 4321: merge the two in LGL')
      expect(address.lgl_review_other_constituent_id).to eq('4321')
      address.lgl_review!('two constituents')
      expect(address.lgl_review_other_constituent_id).to be_nil
    end
  end

  describe 'LGL Lapsed' do
    it 'writes, reads and clears the lapsed tag on the default theater' do
      address.set_lgl_lapsed!('LYBUNT')
      expect(address.lgl_lapsed).to eq('LYBUNT')
      expect(lgl_rows(AddressTag::LGL_LAPSED).pluck(:theater_id)).to eq([house.id])
      address.clear_lgl_lapsed!
      expect(address.lgl_lapsed).to be_nil
    end

    it 'applies a new value, reporting the change' do
      expect(address.apply_lgl_lapsed!('SYBUNT')).to be(true)
      expect(address.lgl_lapsed).to eq('SYBUNT')
      expect(address.apply_lgl_lapsed!('LYBUNT')).to be(true)
      expect(lgl_rows(AddressTag::LGL_LAPSED).pluck(:tag_value)).to eq(['LYBUNT'])
    end

    it 'clears the tag when applying nil' do
      address.set_lgl_lapsed!('LYBUNT')
      expect(address.apply_lgl_lapsed!(nil)).to be(true)
      expect(lgl_rows(AddressTag::LGL_LAPSED)).to be_empty
    end

    it 'writes nothing when the value is unchanged' do
      address.set_lgl_lapsed!('LYBUNT')
      allow(address).to receive(:set_lgl_lapsed!)
      allow(address).to receive(:clear_lgl_lapsed!)

      expect(address.apply_lgl_lapsed!('LYBUNT')).to be(false)
      expect(address).not_to have_received(:set_lgl_lapsed!)
      expect(address).not_to have_received(:clear_lgl_lapsed!)
    end

    it 'reports no change when applying nil to an untagged address' do
      expect(address.apply_lgl_lapsed!(nil)).to be(false)
    end
  end

  describe 'edit-triggered sync' do
    before do
      allow(Lgl).to receive(:enabled?).and_return(true)
      allow(Resque).to receive(:enqueue_in)
    end

    let(:linked) do
      address.set_lgl_id!(42)
      address.reload
    end

    def expect_edit_sync_for(record)
      expect(Resque).to have_received(:enqueue_in)
        .with(LglLinkable::LGL_EDIT_DEBOUNCE, LglSyncAddressJob, record.id, LglSyncAddressJob::EDIT_TRIGGER)
    end

    it 'queues a debounced contact push when a linked address changes its name' do
      linked.update!(full_name: 'Renamed Patron')
      expect_edit_sync_for(linked)
    end

    it 'queues a debounced contact push when a linked address changes its street' do
      linked.update!(line1: '9 New Street')
      expect_edit_sync_for(linked)
    end

    it 'queues a debounced contact push when a linked address changes its phone' do
      linked.update!(phone: '312-555-0100')
      expect_edit_sync_for(linked)
    end

    it 'does not queue when only the email changes' do
      linked.update!(email: 'changed@example.com')
      expect(Resque).not_to have_received(:enqueue_in)
    end

    it 'does not queue for an address with no LGL link' do
      address.update!(full_name: 'Renamed Patron')
      expect(Resque).not_to have_received(:enqueue_in)
    end

    it 'does not queue when LGL is disabled' do
      allow(Lgl).to receive(:enabled?).and_return(false)
      linked.update!(full_name: 'Renamed Patron')
      expect(Resque).not_to have_received(:enqueue_in)
    end

    it 'does not queue while a pull from LGL is saving' do
      linked.lgl_pull_in_progress = true
      linked.update!(phone: '312-555-0100')
      expect(Resque).not_to have_received(:enqueue_in)
    end

    it 'does not queue when only the LGL link itself is written' do
      address.set_lgl_id!(42)
      address.set_lgl_id!(43)
      address.lgl_review!('check me')
      expect(Resque).not_to have_received(:enqueue_in)
    end
  end
end
