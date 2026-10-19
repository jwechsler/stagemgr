# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::ReviewList do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }

  def several(lgl_id)
    "#{Lgl::ConstituentReplicator.several_matches_prefix(lgl_id)} by email and last name"
  end

  # Flags a new address with +reason+, the tag dated +minutes_ago+.
  def flag(reason, minutes_ago:, email: 'pat@example.com', placeholder: false)
    address = FactoryBot.create(:address, email: email, placeholder: placeholder)
    address.lgl_review!(reason)
    address.address_tags.find_by(tag_label: AddressTag::LGL_REVIEW)
           .update_column(:created_at, minutes_ago.minutes.ago)
    address
  end

  describe '#rows and #count' do
    it 'groups the customers matching one constituent into one row, oldest conflict first' do
      first = flag(several(971_217), minutes_ago: 30)
      flag('No LGL match', minutes_ago: 20)
      second = flag(several(971_217), minutes_ago: 10)

      list = described_class.new(limit: 10)

      expect(list.count).to eq(2)
      row = list.rows.first
      expect(row.kind).to eq(:several_matches)
      expect(row.constituent_id).to eq(971_217)
      expect(row.addresses).to eq([first, second])
      expect(row.emails).to eq(['pat@example.com'])
      expect(row.flagged_at).to be_within(1.second).of(30.minutes.ago)
      expect(list.rows.last.reason).to eq('No LGL match')
    end

    it 'groups both wordings for a constituent and keeps other constituents apart' do
      flag("#{Lgl::ConstituentReplicator.several_matches_prefix(12)} named Pat Smith by email: merge them",
           minutes_ago: 3)
      flag(several(12), minutes_ago: 2)
      flag(several(123), minutes_ago: 1)

      rows = described_class.new(limit: 10).rows

      expect(rows.map(&:constituent_id)).to eq([12, 123])
      expect(rows.first.tags.size).to eq(2)
    end

    it 'shows a pair linked to one constituent as one row with the older side\'s reason' do
      older = FactoryBot.create(:address)
      newer = FactoryBot.create(:address)
      older.lgl_review!("LGL constituent 5512 is also linked to ##{newer.id}")
      newer.lgl_review!("LGL constituent 5512 is also linked to ##{older.id}")

      rows = described_class.new(limit: 10).rows

      expect(rows.size).to eq(1)
      expect(rows.first.kind).to eq(:pair)
      expect(rows.first.addresses).to eq([older, newer])
      expect(rows.first.reason).to eq("LGL constituent 5512 is also linked to ##{newer.id}")
    end

    it 'leaves every other reason one row per tag, even when the text matches' do
      flag('Also LGL constituent 77: merge the two in LGL', minutes_ago: 3)
      flag('2 addresses are tagged LGL constituent 77', minutes_ago: 2)
      flag('2 addresses are tagged LGL constituent 77', minutes_ago: 1)

      rows = described_class.new(limit: 10).rows

      expect(rows.map(&:kind)).to eq(%i[other other other])
      expect(rows.map(&:constituent_id)).to all(be_nil)
    end

    it 'applies the limit to rows, not tagged addresses, and counts every row' do
      3.times { |i| flag(several(1), minutes_ago: 10 - i) }
      flag('No LGL match', minutes_ago: 5)
      flag('No LGL match', minutes_ago: 4)

      list = described_class.new(limit: 2)

      expect(list.count).to eq(3)
      expect(list.rows.size).to eq(2)
      expect(list.rows.first.tags.size).to eq(3)
    end

    it 'ignores reviews under another theater' do
      FactoryBot.create(:address).address_tags.create!(tag_label: AddressTag::LGL_REVIEW, tag_value: several(9),
                                                       theater: FactoryBot.create(:theater))

      expect(described_class.new(limit: 10).count).to eq(0)
    end
  end

  describe '.several_matches_addresses' do
    it 'finds the live, non-placeholder customers flagged for that constituent, lowest id first' do
      first = flag(several(44), minutes_ago: 2)
      second = flag(several(44), minutes_ago: 1)
      flag(several(44), minutes_ago: 1, placeholder: true)
      flag(several(440), minutes_ago: 1)
      flag('No LGL match', minutes_ago: 1)
      FactoryBot.create(:address, email: 'pat@example.com')

      expect(described_class.several_matches_addresses(44)).to eq([first, second])
    end
  end
end
