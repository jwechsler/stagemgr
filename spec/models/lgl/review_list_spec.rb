# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::ReviewList do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }

  def several(lgl_id)
    "#{Lgl::ConstituentReplicator.several_matches_prefix(lgl_id)} by email and last name"
  end

  # Flags a new address with +reason+, the tag dated +minutes_ago+.
  def flag(reason, minutes_ago:, email: 'pat@example.com', placeholder: false, name: nil)
    attrs = name ? { full_name: name } : {}
    address = FactoryBot.create(:address, email: email, placeholder: placeholder, **attrs)
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

  describe 'Row#same_person? and #summary' do
    def named(lgl_id)
      Lgl::ConstituentReplicator.several_matches_reason(
        { 'id' => lgl_id, 'first_name' => 'Pat', 'last_name' => 'Smith' },
        [FactoryBot.build(:address, first_name: 'Pat')]
      )
    end

    it 'treats spellings of one first name as one person, counting distinct emails' do
      flag(named(31), minutes_ago: 2, email: 'alden@example.com', name: 'Alden Smith')
      flag(named(31), minutes_ago: 1, email: 'A.SMITH@example.com', name: 'Alden L. Smith')

      row = described_class.new(limit: 10).rows.first

      expect(row.same_person?).to be(true)
      expect(row.first_names).to eq(['Alden'])
      expect(row.summary).to eq('Same first name, 2 emails')
    end

    it 'says one email when the same-named customers share it' do
      2.times { |i| flag(named(32), minutes_ago: i + 1, name: 'Mia Smith') }

      expect(described_class.new(limit: 10).rows.first.summary).to eq('Same first name, 1 email')
    end

    it 'treats different first names as different people, naming them as first typed' do
      flag(several(33), minutes_ago: 3, email: 'glen@example.com', name: 'Glen Smith')
      flag(several(33), minutes_ago: 2, email: 'beth@example.com', name: 'Beth Smith')
      flag(several(33), minutes_ago: 1, email: 'glen@example.com', name: 'glen Smith')

      row = described_class.new(limit: 10).rows.first

      expect(row.same_person?).to be(false)
      expect(row.first_names).to eq(%w[Glen Beth])
      expect(row.summary).to eq('Different first names (Glen, Beth), 2 emails')
    end

    it 'goes by the names, not the wording, when a row mixes both wordings' do
      flag(named(34), minutes_ago: 2, name: 'Mia Smith')
      flag(several(34), minutes_ago: 1, name: 'Mia Smith')

      row = described_class.new(limit: 10).rows.first

      expect(row.same_person?).to be(true)
      expect(row.summary).to eq('Same first name, 1 email')
    end

    it 'ignores a customer with a blank first name' do
      flag(several(36), minutes_ago: 2, name: 'Mia Smith')
      flag(several(36), minutes_ago: 1, name: 'Mia Smith').update_columns(first_name: '', full_name: 'Smith')

      expect(described_class.new(limit: 10).rows.first.same_person?).to be(true)
    end

    it 'checks a set of addresses the same way' do
      glen = FactoryBot.create(:address, full_name: 'Glen Smith')
      beth = FactoryBot.create(:address, full_name: 'Beth Smith')
      glen2 = FactoryBot.create(:address, full_name: 'Glen A. Smith')

      expect(described_class.same_person?([glen, glen2])).to be(true)
      expect(described_class.same_person?([glen, beth])).to be(false)
    end

    it 'labels a pair and leaves any other reason unlabelled' do
      older = FactoryBot.create(:address)
      newer = FactoryBot.create(:address)
      older.lgl_review!("LGL constituent 35 is also linked to ##{newer.id}")
      newer.lgl_review!("LGL constituent 35 is also linked to ##{older.id}")
      flag('No LGL match', minutes_ago: 1)

      rows = described_class.new(limit: 10).rows.index_by(&:kind)
      pair, other = rows.values_at(:pair, :other)

      expect([pair.kind, pair.summary, pair.same_person?]).to eq([:pair, 'Linked to two customers', false])
      expect([other.summary, other.same_person?]).to eq([nil, false])
    end
  end

  describe '.constituent_id_list' do
    it 'lists ids ascending without a serial comma, as constituent_ids_in reads them' do
      list = described_class.constituent_id_list(['9012', 1234, 5678])

      expect(list).to eq('1234, 5678 and 9012')
      expect(described_class.constituent_ids_in("LGL constituents #{list} share this email")).to eq([1234, 5678, 9012])
      expect(described_class.constituent_id_list([12, 11])).to eq('11 and 12')
    end
  end

  describe '.constituent_ids_in' do
    it 'finds every constituent id a reason names, single or listed' do
      expect(described_class.constituent_ids_in('LGL constituents 1234, 5678 and 9012 share this email'))
        .to eq([1234, 5678, 9012])
      expect(described_class.constituent_ids_in('LGL constituents 11 and 12 carry external id 42')).to eq([11, 12])
      expect(described_class.constituent_ids_in('Also LGL constituent 77: merge the two in LGL')).to eq([77])
    end

    it 'ignores customer ids, external ids and reasons naming no constituent' do
      expect(described_class.constituent_ids_in('LGL constituent 5512 is also linked to #5678')).to eq([5512])
      expect(described_class.constituent_ids_in('Same person as #5678 in LGL; merge skipped')).to eq([])
      expect(described_class.constituent_ids_in(nil)).to eq([])
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
