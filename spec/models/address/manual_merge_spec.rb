# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Address::ManualMerge do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }

  def address(**attributes)
    FactoryBot.create(:address, **attributes)
  end

  def review_tags(address)
    AddressTag.where(tag_label: AddressTag::LGL_REVIEW, address_id: address.id)
  end

  describe '#perform!' do
    it 'keeps the lowest id with the newest present values and the newest LGL ID when nothing is chosen' do
      older = address(full_name: 'Pat Older', phone: '555-0001', line1: '1 Old St', city: 'Oldtown',
                      state: 'IL', zipcode: '60601')
      newer = address(full_name: 'Patricia Newer', phone: '', line1: '2 New Ave', line2: 'Apt 3',
                      city: 'Newtown', state: 'WI', zipcode: '53703', email: 'pat@new.example.com')
      older.set_lgl_id!(11)
      newer.set_lgl_id!(22)

      master = described_class.new(ids: [newer.id, older.id]).perform!.reload

      expect(master.id).to eq(older.id)
      expect(Address.exists?(newer.id)).to be(false)
      expect(master.attributes.slice(*%w[full_name first_name last_name line1 line2 city state zipcode email phone]))
        .to eq('full_name' => 'Patricia Newer', 'first_name' => 'Patricia', 'last_name' => 'Newer',
               'line1' => '2 New Ave', 'line2' => 'Apt 3', 'city' => 'Newtown', 'state' => 'WI',
               'zipcode' => '53703', 'email' => 'pat@new.example.com', 'phone' => '555-0001')
      expect(master.lgl_id).to eq('22')
      expect(master.lgl_review_reason).to eq('Also LGL constituent 11: merge the two in LGL')
    end

    it 'clears the LGL Review every record carried' do
      older = address(full_name: 'Pat Older')
      newer = address(full_name: 'Pat Older')
      older.lgl_review!('Several LGL matches')
      newer.lgl_review!('No LGL match')

      master = described_class.new(ids: [older.id, newer.id]).perform!

      expect(review_tags(master)).to be_empty
      expect(AddressTag.where(address_id: newer.id)).to be_empty
    end

    it 'gives the master an explicitly chosen older value over a newer record' do
      older = address(full_name: 'Pat Older', email: 'pat@old.example.com', phone: '555-0001')
      newer = address(full_name: 'Patricia Newer', email: 'pat@new.example.com', phone: '555-0002')

      master = described_class.new(ids: [newer.id, older.id],
                                   choices: { name: older.id, email: older.id, phone: older.id }).perform!.reload

      expect(master.id).to eq(older.id)
      expect([master.full_name, master.first_name, master.last_name]).to eq(['Pat Older', 'Pat', 'Older'])
      expect(master.email).to eq('pat@old.example.com')
      expect(master.phone).to eq('555-0001')
    end

    it 'gives the master a chosen newer name, re-parsing first and last name' do
      older = address(full_name: 'Pat Older')
      newer = address(full_name: 'Patricia Newer')

      master = described_class.new(ids: [older.id, newer.id], choices: { name: newer.id }).perform!.reload

      expect([master.full_name, master.first_name, master.last_name]).to eq(['Patricia Newer', 'Patricia', 'Newer'])
    end

    it 'never lets a blank value win by default' do
      older = address(phone: '555-0001', email: 'pat@old.example.com')
      newer = address(phone: '', email: nil)

      master = described_class.new(ids: [older.id, newer.id]).perform!.reload

      expect(master.phone).to eq('555-0001')
      expect(master.email).to eq('pat@old.example.com')
    end

    it 'moves the chosen address as one unit, blanks included' do
      older = address(line1: '1 Old St', line2: 'Apt 9', city: 'Oldtown', state: 'IL', zipcode: '60601')
      newer = address(line1: '2 New Ave', line2: '', city: 'Newtown', state: 'WI', zipcode: '53703')

      master = described_class.new(ids: [older.id, newer.id]).perform!.reload

      expect(master.attributes.slice('line1', 'line2', 'city', 'state', 'zipcode'))
        .to eq('line1' => '2 New Ave', 'line2' => '', 'city' => 'Newtown', 'state' => 'WI', 'zipcode' => '53703')
    end

    it 'keeps an older chosen address whole even when a newer record has every part' do
      older = address(line1: '1 Old St', line2: nil, city: 'Oldtown', state: 'IL', zipcode: '60601')
      newer = address(line1: '2 New Ave', line2: 'Apt 3', city: 'Newtown', state: 'WI', zipcode: '53703')

      master = described_class.new(ids: [older.id, newer.id], choices: { address: older.id }).perform!.reload

      expect(master.attributes.slice('line1', 'line2', 'city', 'state', 'zipcode'))
        .to eq('line1' => '1 Old St', 'line2' => nil, 'city' => 'Oldtown', 'state' => 'IL', 'zipcode' => '60601')
    end

    it 'keeps the lowest id and re-points orders and memberships from every other record' do
      keeper = FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_cash).address
      ticket_order = FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_cash)
      membership_order = FactoryBot.create(:membership_order)
      membership = membership_order.membership_line_item.membership
      sources = [ticket_order.address, membership_order.address]

      master = described_class.new(ids: sources.map(&:id).reverse + [keeper.id]).perform!

      expect(master.id).to eq(keeper.id)
      expect(ticket_order.reload.address_id).to eq(keeper.id)
      expect(membership_order.reload.address_id).to eq(keeper.id)
      expect(membership.reload.address_id).to eq(keeper.id)
      expect(Address.where(id: sources.map(&:id))).to be_empty
    end

    it 'puts the chosen LGL ID on the master and reviews the other one' do
      older = address
      newer = address
      older.set_lgl_id!(11)
      newer.set_lgl_id!(22)

      master = described_class.new(ids: [older.id, newer.id], choices: { lgl_id: older.id }).perform!

      expect(master.lgl_id).to eq('11')
      expect(master.lgl_review_reason).to eq('Also LGL constituent 22: merge the two in LGL')
      expect(review_tags(master).count).to eq(1)
    end

    it 'names every unchosen LGL ID in one review when three records carry different ids' do
      records = [address, address, address]
      records.zip([11, 22, 33]).each { |record, lgl_id| record.set_lgl_id!(lgl_id) }

      master = described_class.new(ids: records.map(&:id), choices: { lgl_id: records[1].id }).perform!

      expect(master.lgl_id).to eq('22')
      expect(master.lgl_review_reason).to eq('Also LGL constituents 11 and 33: merge them in LGL')
      expect(review_tags(master).count).to eq(1)
    end

    it 'adds no review when the records share one LGL ID' do
      older = address
      newer = address
      older.set_lgl_id!(22)
      newer.set_lgl_id!(22)

      master = described_class.new(ids: [older.id, newer.id], choices: { lgl_id: older.id }).perform!

      expect(master.lgl_id).to eq('22')
      expect(review_tags(master)).to be_empty
    end

    it 'adds no review and keeps the only LGL ID when one record carries it' do
      older = address
      newer = address
      older.set_lgl_id!(11)
      older.lgl_review!('No LGL match')

      master = described_class.new(ids: [older.id, newer.id]).perform!

      expect(master.lgl_id).to eq('11')
      expect(review_tags(master)).to be_empty
    end

    it 'rolls back every merge when saving the chosen values fails' do
      older = address
      newer = address
      merge = described_class.new(ids: [older.id, newer.id])
      allow(merge.master).to receive(:set_lgl_id!).and_raise(ActiveRecord::RecordInvalid)
      newer.set_lgl_id!(22)

      expect { merge.perform! }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Address.where(id: [older.id, newer.id]).count).to eq(2)
    end
  end

  describe 'validation' do
    let!(:older) { address }
    let!(:newer) { address(phone: '') }

    it 'rejects a single customer' do
      expect { described_class.new(ids: [older.id]) }.to raise_error(described_class::Error, /2 to 4/)
    end

    it 'rejects five customers' do
      ids = Array.new(5) { address.id }
      expect { described_class.new(ids: ids) }.to raise_error(described_class::Error, /2 to 4/)
    end

    it 'rejects an unknown customer id' do
      expect { described_class.new(ids: [older.id, 0]) }.to raise_error(described_class::Error, /Unknown customer #0/)
    end

    it 'rejects a choice naming a customer outside the merge' do
      outsider = address
      expect { described_class.new(ids: [older.id, newer.id], choices: { name: outsider.id }) }
        .to raise_error(described_class::Error, /not one of the customers being merged/)
    end

    it 'rejects a choice of a blank value' do
      expect { described_class.new(ids: [older.id, newer.id], choices: { phone: newer.id }) }
        .to raise_error(described_class::Error, /has no phone/)
    end

    it 'rejects an unknown field' do
      expect { described_class.new(ids: [older.id, newer.id], choices: { shoe_size: older.id }) }
        .to raise_error(described_class::Error, /Unknown merge field/)
    end

    it 'accepts string ids and field names as a form posts them' do
      merge = described_class.new(ids: [newer.id.to_s, older.id.to_s], choices: { 'name' => older.id.to_s })

      expect(merge.master).to eq(older)
      expect(merge.choice_for(:name)).to eq(older.id)
    end
  end

  describe 'read helpers' do
    let!(:older) do
      address(full_name: 'Pat Older', email: 'Pat@Example.com', phone: '555-0001',
              line1: '1 Old St', line2: 'Apt 9', city: 'Oldtown', state: 'IL', zipcode: '60601')
    end
    let!(:newer) do
      address(full_name: 'Pat  Older', email: 'pat@example.com', phone: '',
              line1: '', line2: '', city: '', state: '', zipcode: '')
    end
    let(:merge) { described_class.new(ids: [older.id, newer.id], choices: { name: older.id }) }

    it 'shows each record\'s value, one-line address and nil for a blank' do
      expect(merge.values_for(:address))
        .to eq(older.id => '1 Old St, Apt 9, Oldtown, IL 60601', newer.id => nil)
      expect(merge.values_for(:phone)).to eq(older.id => '555-0001', newer.id => nil)
    end

    it 'does not count spacing or email case as a difference' do
      expect(merge.differs?(:name)).to be(false)
      expect(merge.differs?(:email)).to be(false)
    end

    it 'counts different present values as a difference, but not a single value against blanks' do
      third = address(full_name: 'Patricia Older')
      merge = described_class.new(ids: [older.id, newer.id, third.id])

      expect(merge.differs?(:name)).to be(true)
      expect(merge.differs?(:phone)).to be(false)
    end

    it 'defaults to the newest record with a value and nil when none has one' do
      expect(merge.default_for(:email)).to eq(newer.id)
      expect(merge.default_for(:phone)).to eq(older.id)
      expect(merge.default_for(:lgl_id)).to be_nil
    end

    it 'prefers an explicit choice over the default' do
      expect(merge.choice_for(:name)).to eq(older.id)
      expect(merge.choice_for(:email)).to eq(newer.id)
    end

    it 'exposes the fields in order with their columns' do
      expect(described_class::FIELDS).to eq(%i[name address email phone lgl_id])
      expect(described_class::COLUMNS[:address]).to eq(%i[line1 line2 city state zipcode])
    end
  end

  describe 'excluded records' do
    it 'merges the rest into the unchanged master and leaves an excluded highest id untouched' do
      older = address(full_name: 'Pat Older')
      middle = address(full_name: 'Pat Middle')
      excluded_order = FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_cash)
      excluded = excluded_order.address
      excluded.update!(full_name: 'Pat Excluded')
      excluded.lgl_review!('Several LGL matches')

      master = described_class.new(ids: [older.id, middle.id, excluded.id], excluded: [excluded.id]).perform!.reload

      expect(master.id).to eq(older.id)
      expect(master.full_name).to eq('Pat Middle')
      expect(Address.exists?(middle.id)).to be(false)
      expect(excluded.reload.full_name).to eq('Pat Excluded')
      expect(excluded_order.reload.address_id).to eq(excluded.id)
      expect(review_tags(excluded).count).to eq(1)
    end

    it 'makes the next-lowest merged id the master when the lowest is excluded' do
      lowest = address
      middle = address
      highest = address

      merge = described_class.new(ids: [lowest.id, middle.id, highest.id], excluded: [lowest.id])

      expect(merge.master).to eq(middle)
      expect(merge.merged_ids).to eq([middle.id, highest.id])
      expect(merge.perform!.id).to eq(middle.id)
      expect(Address.exists?(highest.id)).to be(false)
      expect(Address.exists?(lowest.id)).to be(true)
    end

    it 'never counts an excluded value as a difference or makes it the default, even when newest' do
      older = address(full_name: 'Pat Older', email: 'pat@example.com')
      newer = address(full_name: 'Pat Older', email: nil)
      newest = address(full_name: 'Someone Else', email: 'else@example.com')

      merge = described_class.new(ids: [older.id, newer.id, newest.id], excluded: [newest.id])

      expect(merge.values_for(:name)).to include(newest.id => 'Someone Else')
      expect(merge.differs?(:name)).to be(false)
      expect(merge.differs?(:email)).to be(false)
      expect(merge.default_for(:name)).to eq(newer.id)
      expect(merge.default_for(:email)).to eq(older.id)
      expect(merge.choice_for(:email)).to eq(older.id)
    end

    it 'rejects a choice naming an excluded customer' do
      records = [address, address, address]

      expect { described_class.new(ids: records.map(&:id), excluded: [records[2].id], choices: { name: records[2].id }) }
        .to raise_error(described_class::Error, /##{records[2].id} for name is not one of the customers being merged/)
    end

    it 'rejects an excluded id that was not submitted' do
      older = address
      newer = address
      outsider = address

      expect { described_class.new(ids: [older.id, newer.id], excluded: [outsider.id]) }
        .to raise_error(described_class::Error, "Customer ##{outsider.id} is not one of the customers submitted")
    end

    it 'applies the 2 to 4 count to the merged records' do
      records = [address, address, address]

      expect { described_class.new(ids: records.map(&:id), excluded: records.drop(1).map(&:id)) }
        .to raise_error(described_class::Error, /2 to 4 customers to merge \(got 1\)/)
    end

    it 'accepts string excluded ids as a form posts them' do
      records = [address, address, address]

      merge = described_class.new(ids: records.map { |r| r.id.to_s }, excluded: [records[0].id.to_s])

      expect(merge.excluded_ids).to eq([records[0].id])
      expect(merge.master).to eq(records[1])
    end

    it 'lists excluded and merged addresses in id order and answers excluded? for an Address or an id' do
      records = [address, address, address, address]
      merge = described_class.new(ids: records.map(&:id).reverse, excluded: [records[3].id, records[1].id])

      expect(merge.ids).to eq(records.map(&:id))
      expect(merge.excluded_addresses).to eq([records[1], records[3]])
      expect(merge.merged_addresses).to eq([records[0], records[2]])
      expect(merge.excluded?(records[1])).to be(true)
      expect(merge.excluded?(records[3].id)).to be(true)
      expect(merge.excluded?(records[0])).to be(false)
      expect(merge.excluded?(records[2].id)).to be(false)
    end
  end
end
