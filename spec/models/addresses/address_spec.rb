require 'rails_helper'

RSpec.describe 'a customer record' do
  include_context 'auto-fulfilling print service'

  it 'should merge/purge production attendance records' do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
    o.transition_to!(Order::FULFILLED)
    original_address = o.address
    expect(original_address.productions.size).to equal(1)
    o2 = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
    expect(o2.performance.production_id).not_to equal(o.performance.production_id)
    purge_address = original_address.dup
    purge_address.full_name = purge_address.full_name + '-updated'
    purge_address.save
    o2.address = purge_address
    o2.save!
    o2.transition_to!(Order::FULFILLED)
    expect(purge_address.productions.count).to eq(1)
    original_address.merge_and_purge(purge_address)
    expect(original_address.last_name).to match(/(.*)-updated/)
    expect(original_address.productions.size).to equal(2)
  end

  describe '#merge_and_purge foreign key coverage' do
    let(:keeper) { FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_cash).address }
    let(:order) { FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_cash) }
    let(:duplicate) { order.address }

    it 'moves line_items, payments, and pledges off the purged address' do
      line_item = order.ticket_line_items.first
      line_item.update_columns(address_id: duplicate.id)
      payment = order.payments.first
      payment.update_columns(address_id: duplicate.id)
      pledge = Pledge.create!(address: duplicate)

      keeper.merge_and_purge(duplicate)

      expect(line_item.reload.address_id).to eq(keeper.id)
      expect(payment.reload.address_id).to eq(keeper.id)
      expect(pledge.reload.address_id).to eq(keeper.id)
      expect(Address.exists?(duplicate.id)).to be(false)
    end

    it 'takes the newer address email and refreshes External ID tags per theater' do
      theater_a = keeper.orders.first.theater
      theater_b = FactoryBot.create(:theater)
      keeper.update!(email: 'old.email@example.com')
      keeper.address_tags.create!(tag_label: AddressTag::EXTERNAL_ID, tag_value: 'A-OLD', theater: theater_a)
      duplicate.update!(email: 'new.email@example.com')
      duplicate.address_tags.create!(tag_label: AddressTag::EXTERNAL_ID, tag_value: 'A-NEW', theater: theater_a)
      duplicate.address_tags.create!(tag_label: AddressTag::EXTERNAL_ID, tag_value: 'B-NEW', theater: theater_b)

      keeper.merge_and_purge(duplicate)
      keeper.reload

      expect(keeper.email).to eq('new.email@example.com')
      # Same theater: the existing tag's value is updated in place, not duplicated.
      expect(keeper.external_id([theater_a.id])).to eq('A-NEW')
      expect(keeper.address_tags.where(tag_label: AddressTag::EXTERNAL_ID, theater: theater_a).count).to eq(1)
      # New theater: the tag is carried over.
      expect(keeper.external_id([theater_b.id])).to eq('B-NEW')
    end

    it 'leaves no address_tags pointing at the purged address' do
      theater = keeper.orders.first.theater
      keeper.address_tags.create!(tag_label: 'press', tag_value: '1', theater: theater)
      duplicate.address_tags.create!(tag_label: 'press', tag_value: '1', theater: theater) # exact duplicate
      duplicate.address_tags.create!(tag_label: 'donor', tag_value: '1', theater: theater) # new to keeper

      keeper.merge_and_purge(duplicate)

      expect(AddressTag.where(address_id: duplicate.id)).to be_empty
      expect(keeper.reload.address_tags.pluck(:tag_label)).to contain_exactly('press', 'donor')
    end
  end
end
