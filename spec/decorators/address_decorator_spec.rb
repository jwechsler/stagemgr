require 'rails_helper'

RSpec.describe AddressDecorator do
  describe '#description' do
    let(:address) { FactoryBot.create(:address) }
    let(:theater_user) { FactoryBot.create(:user) }
    let(:admin_user) { FactoryBot.create(:admin_user) }

    context 'when the address has an active membership' do
      let!(:membership_order) { FactoryBot.create(:membership_order, address: address) }
      let(:membership) { membership_order.membership }

      before do
        membership.membership_offer.update!(name: 'Gold <Circle> Membership')
        membership.update!(member_code: 'GOLD123')
      end

      it 'shows a theater user the escaped offer name without the member code or a link' do
        text = address.decorate.description(theater_user)
        member_part = text[/Member \[.*\]/]

        expect(member_part).to eq('Member [Gold &lt;Circle&gt; Membership]')
        expect(text).not_to include('GOLD123')
        expect(member_part).not_to include('<a')
      end

      it 'shows an administrator the member code linked to the membership order' do
        text = address.decorate.description(admin_user)
        order_path = Rails.application.routes.url_helpers.polymorphic_path([:admin, membership_order])

        expect(text).to include('Member [')
        expect(text).to include("<a href=\"#{order_path}\">GOLD123</a>")
        expect(text).not_to include('Gold')
      end
    end

    it 'omits the Member part when the address has no active membership' do
      expect(address.decorate.description(theater_user)).not_to include('Member')
      expect(address.decorate.description(admin_user)).not_to include('Member')
    end
  end
end
