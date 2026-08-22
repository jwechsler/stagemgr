require 'rails_helper'

RSpec.describe Admin::DefaultTicketClassesController, type: :controller do
  let(:admin_user) { FactoryBot.create(:admin_user) }

  before do
    allow(controller).to receive(:current_user).and_return(admin_user)
    allow(controller).to receive(:authorize!).and_return(true)
  end

  def valid_params(overrides = {})
    { class_code: 'ZONEP', class_name: 'Zone Probe', ticket_type: 'Fixed',
      ticket_price: '10.00', ticketing_fee: '1.00' }.merge(overrides)
  end

  describe 'GET #new' do
    render_views

    # Regression: the shared admin/ticket_classes/_fields partial renders
    # f.input :zone_id, which raised NoMethodError until default_ticket_classes
    # grew the same column.
    it 'renders the shared ticket class fields including the zone input' do
      get :new

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('default_ticket_class[zone_id]')
    end
  end

  describe 'POST #create' do
    it 'persists the normalized zone' do
      post :create, params: { default_ticket_class: valid_params(zone_id: 'b1') }

      expect(DefaultTicketClass.find_by(class_code: 'ZONEP').zone_id).to eq('B1')
    end

    it 'defaults to the wildcard zone when none is supplied' do
      post :create, params: { default_ticket_class: valid_params }

      expect(DefaultTicketClass.find_by(class_code: 'ZONEP').zone_id).to eq(ZoneMatchable::WILDCARD)
    end

    # These three are rendered by the shared _fields partial but were missing
    # from the permit list, so the checkboxes silently kept their column
    # defaults (false / true / false).
    it 'persists the option flags the shared form renders' do
      post :create, params: { default_ticket_class: valid_params(assigns_seats: '1',
                                                                 show_in_pricing_range: '0',
                                                                 complimentary: '1') }

      default_class = DefaultTicketClass.find_by(class_code: 'ZONEP')
      expect(default_class.assigns_seats).to be true
      expect(default_class.show_in_pricing_range).to be false
      expect(default_class.complimentary).to be true
    end
  end

  describe 'PATCH #update' do
    it 'persists the option flags the shared form renders' do
      default_class = DefaultTicketClass.create!(valid_params)

      patch :update, params: { id: default_class.id,
                               default_ticket_class: valid_params(assigns_seats: '1',
                                                                  show_in_pricing_range: '0',
                                                                  complimentary: '1') }

      default_class.reload
      expect(default_class.assigns_seats).to be true
      expect(default_class.show_in_pricing_range).to be false
      expect(default_class.complimentary).to be true
    end
  end
end
