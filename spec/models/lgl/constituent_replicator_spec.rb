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

  def person(last_name, email, **attrs)
    FactoryBot.create(:address, full_name: "Pat #{last_name}", last_name: last_name, email: email, **attrs)
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

      expect(described_class.match_by_email(constituent)).to eq([:one_match, smith])
    end

    it 'reports several when more than one address matches' do
      person('SMITH', 'smith@example.com')

      expect(described_class.match_by_email(lgl(910_001, emails: [email('smith@example.com')])))
        .to eq([:several_matches, nil])
    end

    it 'reports no match for a different last name, a placeholder or another LGL ID' do
      person('Held', 'held@example.com', placeholder: true)
      person('Other', 'other@example.com').set_lgl_id!(910_099)

      expect(described_class.match_by_email(lgl(910_001, last: 'Jones', emails: [email('smith@example.com')])))
        .to eq([:no_match, nil])
      expect(described_class.match_by_email(lgl(910_001, last: 'Held', emails: [email('held@example.com')])))
        .to eq([:no_match, nil])
      expect(described_class.match_by_email(lgl(910_001, last: 'Other', emails: [email('other@example.com')])))
        .to eq([:no_match, nil])
    end

    it 'matches an address already tagged with this same constituent' do
      smith.set_lgl_id!(910_001)

      expect(described_class.match_by_email(lgl(910_001, emails: [email('smith@example.com')])))
        .to eq([:one_match, smith])
    end

    it 'reports no email when the constituent has none' do
      expect(described_class.match_by_email(lgl(910_001))).to eq([:no_email, nil])
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

    it 'flags every match for review when several match' do
      matches = [person('Smith', 'smith@example.com'), person('Smith', 'smith@example.com')]

      result = described_class.new(lgl(920_003, emails: [email('smith@example.com')])).apply!

      expect([result.outcome, result.address]).to eq([:review, nil])
      expect(matches.map(&:lgl_review_reason))
        .to all(eq('LGL constituent 920003 matches several customers by email and last name'))
      expect(matches.map(&:lgl_id)).to all(be_nil)
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
  end
end
