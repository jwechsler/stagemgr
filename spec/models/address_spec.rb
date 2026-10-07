require 'rails_helper'

RSpec.describe Address do
  describe '#is_current_member?' do
    it 'is true for a patron with an active membership bought through an order' do
      order = FactoryBot.create(:membership_order)

      expect(order.address.is_current_member?).to be(true)
      expect(order.address.active_memberships).to eq([order.membership_line_item.membership])
    end

    it 'is false for a patron who holds only a library pass' do
      pass = FactoryBot.create(:library_pass, address: FactoryBot.create(:address))

      expect(pass.address.is_current_member?).to be(false)
      expect(pass.address.active_memberships).to be_empty
    end
  end
end
