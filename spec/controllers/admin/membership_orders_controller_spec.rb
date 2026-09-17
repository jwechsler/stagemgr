require 'rails_helper'

RSpec.describe Admin::MembershipOrdersController, type: :controller do
  render_views

  let(:admin_user) { FactoryBot.create(:admin_user) }
  let(:membership_order) { FactoryBot.create(:membership_order) }
  let(:membership) { membership_order.membership_line_item.membership }
  let(:offer) { membership.membership_offer }

  before do
    allow(controller).to receive(:current_user).and_return(admin_user)
    allow_any_instance_of(Membership).to receive(:update_from_profile!)
  end

  describe 'GET #show' do
    it 'offers no card button and points at the offer while it has no background' do
      get :show, params: { id: membership_order.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Generate Member ID Card')
      expect(response.body).to include('No ID card template is uploaded for this offer')
      expect(response.body).to include(edit_admin_membership_offer_path(offer))
    end

    it 'shows the card button in the membership block once the offer has a background', :membership_cards do
      offer.card_background.attach(blob_for(synthetic_background, 'bg.png'))

      get :show, params: { id: membership_order.id }

      expect(response.body).to include('Generate Member ID Card')
      expect(response.body).to include(id_card_admin_membership_path(membership))
      expect(response.body).to include('no photo on file')
    end
  end
end
