# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::ConstituentReplicator do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }

  def lgl(id, first: 'Pat', last: 'Smith', emails: [], streets: [], phones: [], **extra)
    { 'id' => id, 'external_constituent_id' => '', 'first_name' => first, 'last_name' => last,
      'email_addresses' => emails, 'street_addresses' => streets, 'phone_numbers' => phones }.merge(extra.stringify_keys)
  end

  def email(address, preferred: false)
    { 'address' => address, 'is_preferred' => preferred }
  end

  def person(last_name, email, first: 'Pat', **attrs)
    FactoryBot.create(:address, full_name: "#{first} #{last_name}", last_name: last_name, email: email, **attrs)
  end

  describe '.skip_reason' do
    it 'skips organisations' do
      expect(described_class.skip_reason(lgl(1, emails: [email('a@example.com')], is_org: true))).to eq(:org_skipped)
    end

    it 'skips a constituent with neither an email nor a street' do
      expect(described_class.skip_reason(lgl(1, phones: [{ 'number' => '312-555-0100' }]))).to eq(:no_contact)
    end

    it 'skips a constituent with no first or last name' do
      expect(described_class.skip_reason(lgl(1, first: ' ', last: nil, emails: [email('a@example.com')])))
        .to eq(:no_name)
    end

    it 'accepts a named person with an email or a street' do
      expect(described_class.skip_reason(lgl(1, emails: [email('a@example.com')]))).to be_nil
      expect(described_class.skip_reason(lgl(1, last: '', streets: [{ 'street' => '1 Main St' }]))).to be_nil
    end
  end

  describe '.match_by_email' do
    let!(:smith) { person('Smith', 'smith@example.com') }

    it 'finds the one address with an LGL email and the same last name, ignoring case' do
      constituent = lgl(910_001, last: 'smith', emails: [email('other@example.com'), email('SMITH@example.com')])

      expect(described_class.match_by_email(constituent)).to eq([:one_match, smith, []])
    end

    it 'reports several, all to flag, when more than one address matches' do
      other = person('SMITH', 'smith@example.com')

      expect(described_class.match_by_email(lgl(910_001, emails: [email('smith@example.com')])))
        .to eq([:several_matches, nil, [smith, other]])
    end

    context 'with a couple sharing one email' do
      let!(:charles) { person('Kosalko', 'kosalko@example.com', first: 'Charles') }
      let!(:gayle) { person('Kosalko', 'kosalko@example.com', first: 'Gayle') }

      it "links the one address with the constituent's first name" do
        constituent = lgl(910_010, first: 'Charles', last: 'Kosalko', emails: [email('kosalko@example.com')])

        expect(described_class.match_by_email(constituent)).to eq([:one_match, charles, []])
      end

      it 'flags them all when none shares the first name' do
        constituent = lgl(910_010, first: 'Chuck', last: 'Kosalko', emails: [email('kosalko@example.com')])

        expect(described_class.match_by_email(constituent)).to eq([:several_matches, nil, [charles, gayle]])
      end

      it 'links by first name even when a stray record has no first name' do
        stray = person('Kosalko', 'kosalko@example.com')
        stray.update_column(:first_name, nil)
        constituent = lgl(910_010, first: 'Charles', last: 'Kosalko', emails: [email('kosalko@example.com')])

        expect(described_class.match_by_email(constituent)).to eq([:one_match, charles, []])
      end

      it "does not narrow when the constituent's first name is blank" do
        constituent = lgl(910_010, first: '', last: 'Kosalko', emails: [email('kosalko@example.com')])

        expect(described_class.match_by_email(constituent)).to eq([:several_matches, nil, [charles, gayle]])
      end
    end

    it 'flags only the spellings of the first name when several share it' do
      robert = person('Holliday', 'holliday@example.com', first: 'Robert')
      robert_l = person('Holliday', 'holliday@example.com', first: 'Robert L.')
      person('Holliday', 'holliday@example.com', first: 'Ann')
      constituent = lgl(910_011, first: 'Robert', last: 'Holliday', emails: [email('holliday@example.com')])

      expect(described_class.match_by_email(constituent)).to eq([:several_matches, nil, [robert, robert_l]])
    end

    it 'reports no match for a different last name, a placeholder or another LGL ID' do
      person('Held', 'held@example.com', placeholder: true)
      person('Other', 'other@example.com').set_lgl_id!(910_099)

      expect(described_class.match_by_email(lgl(910_001, last: 'Jones', emails: [email('smith@example.com')])))
        .to eq([:no_match, nil, []])
      expect(described_class.match_by_email(lgl(910_001, last: 'Held', emails: [email('held@example.com')])))
        .to eq([:no_match, nil, []])
      expect(described_class.match_by_email(lgl(910_001, last: 'Other', emails: [email('other@example.com')])))
        .to eq([:no_match, nil, []])
    end

    it 'matches an address already tagged with this same constituent' do
      smith.set_lgl_id!(910_001)

      expect(described_class.match_by_email(lgl(910_001, emails: [email('smith@example.com')])))
        .to eq([:one_match, smith, []])
    end

    it 'reports no email when the constituent has none' do
      expect(described_class.match_by_email(lgl(910_001))).to eq([:no_email, nil, []])
    end
  end

  describe '.build_address' do
    it 'maps the name and the preferred email, street and phone' do
      constituent = lgl(
        1, first: 'Pat', last: 'Smith',
           emails: [email('old@example.com'), email('pat@example.com', preferred: true)],
           streets: [{ 'street' => '9 Old Rd', 'city' => 'Evanston' },
                     { 'street' => "1 Main St\nApt 2", 'city' => 'Chicago', 'state' => 'IL',
                       'postal_code' => '60601', 'is_preferred' => true }],
           phones: [{ 'number' => '312-555-0100' }, { 'number' => '773-555-0199', 'is_preferred' => true }]
      )

      address = described_class.build_address(constituent)

      expect(address).to be_new_record
      expect(address.attributes.slice('full_name', 'email', 'line1', 'line2', 'city', 'state', 'zipcode', 'phone'))
        .to eq('full_name' => 'Pat Smith', 'email' => 'pat@example.com', 'line1' => '1 Main St', 'line2' => 'Apt 2',
               'city' => 'Chicago', 'state' => 'IL', 'zipcode' => '60601', 'phone' => '773-555-0199')
      expect(address.placeholder).to be(false)
    end

    it 'falls back to the first entry when none is preferred' do
      constituent = lgl(1, last: '', emails: [email('first@example.com'), email('second@example.com')],
                           phones: [{ 'number' => '312-555-0100' }])

      address = described_class.build_address(constituent)

      expect([address.full_name, address.email, address.phone]).to eq(['Pat', 'first@example.com', '312-555-0100'])
      expect(address.line1).to be_nil
    end
  end

  describe '#apply!' do
    it 'creates an address tagged with the constituent in one save' do
      constituent = lgl(920_001, emails: [email('new@example.com')])

      result = nil
      expect { result = described_class.new(constituent).apply! }.to change(Address, :count).by(1)

      expect(result.outcome).to eq(:created)
      expect(result.address).to be_persisted
      expect(result.address.reload.lgl_id).to eq('920001')
      expect([result.address.full_name, result.address.email]).to eq(['Pat Smith', 'new@example.com'])
    end

    it 'queues no edit push when creating' do
      allow(Lgl).to receive(:enabled?).and_return(true)
      allow(Resque).to receive(:enqueue_in)

      described_class.new(lgl(920_001, emails: [email('new@example.com')])).apply!

      expect(Resque).not_to have_received(:enqueue_in)
    end

    it 'links the one matching address and clears its review' do
      smith = person('Smith', 'smith@example.com')
      smith.lgl_review!('old')

      result = nil
      expect { result = described_class.new(lgl(920_002, emails: [email('smith@example.com')])).apply! }
        .not_to change(Address, :count)

      expect([result.outcome, result.address]).to eq([:linked, smith])
      expect(smith.lgl_id).to eq('920002')
      expect(smith.lgl_review_reason).to be_nil
    end

    it 'flags every match when several match and none shares the first name' do
      matches = [person('Smith', 'smith@example.com', first: 'Lee'), person('Smith', 'smith@example.com', first: 'Kim')]

      result = described_class.new(lgl(920_003, emails: [email('smith@example.com')])).apply!

      expect([result.outcome, result.address]).to eq([:review, nil])
      expect(matches.map(&:lgl_review_reason))
        .to all(eq('LGL constituent 920003 matches several customers by email and last name'))
      expect(matches.map(&:lgl_id)).to all(be_nil)
    end

    it 'flags every match the old way when the constituent has no first name' do
      matches = [person('Smith', 'smith@example.com'), person('Smith', 'smith@example.com')]

      described_class.new(lgl(920_003, first: nil, emails: [email('smith@example.com')])).apply!

      expect(matches.map(&:lgl_review_reason))
        .to all(eq('LGL constituent 920003 matches several customers by email and last name'))
    end

    it 'flags only the customers sharing the first name, asking for a merge' do
      roberts = [person('Holliday', 'holliday@example.com', first: 'Robert'),
                 person('Holliday', 'holliday@example.com', first: 'Robert L')]
      spouse = person('Holliday', 'holliday@example.com', first: 'Ann')

      result = described_class.new(lgl(920_007, first: 'Robert', last: 'Holliday',
                                                emails: [email('holliday@example.com')])).apply!

      expect(result.outcome).to eq(:review)
      named = 'LGL constituent 920007 matches several customers named Robert Holliday by email: ' \
              'merge them in Stagemgr, then Re-sync'
      expect(roberts.map(&:lgl_review_reason)).to all(eq(named))
      expect(spouse.lgl_review_reason).to be_nil
    end

    it "links by first name and clears the spouse's stale review for this constituent only" do
      charles = person('Kosalko', 'kosalko@example.com', first: 'Charles')
      gayle = person('Kosalko', 'kosalko@example.com', first: 'Gayle')
      [charles, gayle].each { |a| a.lgl_review!('LGL constituent 920008 matches several customers by email and last name') }
      other = person('Kosalko', 'kosalko@example.com', first: 'Gayle Ann')
      other.lgl_review!('LGL constituent 920009 matches several customers by email and last name')

      result = described_class.new(lgl(920_008, first: 'Charles', last: 'Kosalko',
                                                emails: [email('kosalko@example.com')])).apply!

      expect([result.outcome, result.address]).to eq([:linked, charles])
      expect([charles, gayle].map(&:lgl_review_reason)).to all(be_nil)
      expect(other.lgl_review_reason).to eq('LGL constituent 920009 matches several customers by email and last name')
    end

    it "replaces the old wording on a re-flag and clears the spouse's" do
      roberts = [person('Holliday', 'holliday@example.com', first: 'Robert'),
                 person('Holliday', 'holliday@example.com', first: 'Robert')]
      spouse = person('Holliday', 'holliday@example.com', first: 'Ann')
      (roberts + [spouse]).each { |a| a.lgl_review!('LGL constituent 920010 matches several customers by email and last name') }

      described_class.new(lgl(920_010, first: 'Robert', last: 'Holliday', emails: [email('holliday@example.com')])).apply!

      expect(roberts.map(&:lgl_review_reason)).to all(include('matches several customers named Robert Holliday'))
      expect(spouse.lgl_review_reason).to be_nil
    end

    it "clears this constituent's review from a customer whose email no longer matches" do
      moved = person('Holliday', 'old@example.com', first: 'Robert')
      current = person('Holliday', 'holliday@example.com', first: 'Robert')
      [moved, current].each { |a| a.lgl_review!('LGL constituent 920011 matches several customers by email and last name') }

      result = described_class.new(lgl(920_011, first: 'Robert', last: 'Holliday',
                                                emails: [email('holliday@example.com')])).apply!

      expect([result.outcome, result.address]).to eq([:linked, current])
      expect([moved.reload, current.reload].map(&:lgl_review_reason)).to all(be_nil)
    end

    it "clears this constituent's review when it now matches no customer and a new one is created" do
      dropped = person('Holliday', 'old@example.com', first: 'Robert')
      dropped.lgl_review!('LGL constituent 920012 matches several customers by email and last name')
      other = person('Holliday', 'old@example.com', first: 'Ann')
      other.lgl_review!('LGL constituent 920013 matches several customers by email and last name')

      result = described_class.new(lgl(920_012, first: 'Robert', last: 'Holliday',
                                                emails: [email('robert.new@example.com')])).apply!

      expect(result.outcome).to eq(:created)
      expect(dropped.reload.lgl_review_reason).to be_nil
      expect(other.reload.lgl_review_reason).to eq('LGL constituent 920013 matches several customers by email and last name')
    end

    it 'creates nothing when another run tagged an address with the constituent first' do
      person('Elsewhere', 'elsewhere@example.com').set_lgl_id!(920_004)

      result = nil
      expect { result = described_class.new(lgl(920_004, emails: [email('new@example.com')])).apply! }
        .not_to change(Address, :count)

      expect([result.outcome, result.address]).to eq([:already_tagged, nil])
    end

    it 'creates nothing when the email is not one Address accepts' do
      result = nil
      expect { result = described_class.new(lgl(920_005, emails: [email('pat@@example..com')])).apply! }
        .not_to change(Address, :count)

      expect([result.outcome, result.address]).to eq([:invalid_email, nil])
    end

    it 'returns the skip reason without writing' do
      expect { expect(described_class.new(lgl(920_006, is_org: true)).apply!.outcome).to eq(:org_skipped) }
        .not_to change(Address, :count)
    end

    context 'with create: false' do
      it 'creates nothing when no customer matches and clears its stale several-matches review' do
        dropped = person('Holliday', 'old@example.com', first: 'Robert')
        dropped.lgl_review!('LGL constituent 920020 matches several customers by email and last name')

        result = nil
        expect do
          result = described_class.new(lgl(920_020, first: 'Robert', last: 'Holliday',
                                                    emails: [email('robert.new@example.com')]), create: false).apply!
        end.not_to change(Address, :count)

        expect([result.outcome, result.address]).to eq([:not_created, nil])
        expect(dropped.reload.lgl_review_reason).to be_nil
        expect(AddressTag.lgl(AddressTag::LGL_ID).exists?(tag_value: '920020')).to be(false)
      end

      it 'creates nothing for an email-only name' do
        constituent = lgl(920_021, first: nil, last: 'echuukwu@example.org', emails: [email('echuukwu@example.org')])

        result = nil
        expect { result = described_class.new(constituent, create: false).apply! }.not_to change(Address, :count)

        expect(result.outcome).to eq(:not_created)
      end

      it 'still links the one matching address' do
        smith = person('Smith', 'smith@example.com')

        result = described_class.new(lgl(920_022, emails: [email('smith@example.com')]), create: false).apply!

        expect([result.outcome, result.address]).to eq([:linked, smith])
        expect(smith.reload.lgl_id).to eq('920022')
      end

      it 'still flags every match when several match' do
        smiths = [person('Smith', 'smith@example.com', first: 'Ann'), person('Smith', 'smith@example.com', first: 'Bo')]

        result = described_class.new(lgl(920_023, emails: [email('smith@example.com')]), create: false).apply!

        expect(result.outcome).to eq(:review)
        expect(smiths.map { |address| address.reload.lgl_review_reason })
          .to all(eq('LGL constituent 920023 matches several customers by email and last name'))
      end
    end
  end
end
