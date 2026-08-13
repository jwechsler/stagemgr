require 'rails_helper'

# The gift-recipient address used to be saved BEFORE checking find_original
# (a second, shadowing definition of create_recipient_address), orphaning a
# duplicate record whenever the recipient already existed.
RSpec.describe Order, type: :model do
  describe '#create_recipient_address' do
    it 'reuses an existing address for a known recipient without creating a duplicate' do
      existing = FactoryBot.create(:address, full_name: 'Robin Recipient',
                                             email: 'robin@example.com')

      expect do
        order = FactoryBot.create(:ticket_order, :for_a_single_ticket,
                                  gift: true,
                                  recipient_name: 'Robin Recipient',
                                  recipient_email: 'robin@example.com')
        expect(order.recipient_address_id).to eq(existing.id)
      end.to change(Address, :count).by(1) # only the buyer's own address
    end

    it 'creates exactly one new address for an unknown recipient' do
      expect do
        FactoryBot.create(:ticket_order, :for_a_single_ticket,
                          gift: true,
                          recipient_name: 'Nova Newperson',
                          recipient_email: 'nova@example.com')
      end.to change(Address, :count).by(2) # buyer + recipient, no orphan
    end
  end
end
