require 'rails_helper'

# The Little Green Light block on the donation order page.
RSpec.describe Admin::DonationOrdersController, type: :controller do
  render_views

  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:admin_user) { FactoryBot.create(:admin_user) }
  # A processed donation: the page for an editable (NEW) one redirects to edit.
  let(:donation) { FactoryBot.create(:donation_order).tap { |o| o.update_column(:status, Order::PROCESSED) } }

  before { allow(controller).to receive(:current_user).and_return(admin_user) }

  context 'when LGL is enabled' do
    before { allow(Lgl).to receive(:enabled?).and_return(true) }

    it 'shows the LGL gift id and the Send to LGL button' do
      donation.update_column(:lgl_gift_id, 98_765)

      get :show, params: { id: donation.id }

      block = Nokogiri::HTML(response.body).at_css('#lgl-gift')
      expect(block.text.squish).to include('Little Green Light: Gift #98765')
      expect(block.to_html).to include('Send to LGL', lgl_replicate_admin_order_path(donation))
    end

    it 'says the donation is not in LGL and links the constituent' do
      donation.address.set_lgl_id!(4321)
      allow(Lgl).to receive(:constituent_url).with('4321')
                                             .and_return('https://house.littlegreenlight.com/constituents/4321')

      get :show, params: { id: donation.id }

      block = Nokogiri::HTML(response.body).at_css('#lgl-gift')
      expect(block.text.squish).to include('Little Green Light: not in LGL', 'constituent 4321')
      expect(block.to_html).to include('href="https://house.littlegreenlight.com/constituents/4321"')
    end

    it 'hides the block from a box office user' do
      allow(controller).to receive(:current_user).and_return(FactoryBot.create(:user, is_box_office_user: true))

      get :show, params: { id: donation.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Send to LGL')
    end
  end

  it 'hides the block when LGL is disabled' do
    get :show, params: { id: donation.id }

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('Send to LGL')
  end
end
