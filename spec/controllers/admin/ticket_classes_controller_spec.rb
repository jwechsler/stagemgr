require 'rails_helper'

RSpec.describe Admin::TicketClassesController, type: :controller do
  let(:admin_user) { FactoryBot.create(:admin_user) }
  let(:production) { FactoryBot.create(:production) }
  let(:theater) { production.theater }

  before do
    allow(controller).to receive(:current_user).and_return(admin_user)
    allow(controller).to receive(:authorize!).and_return(true)
  end

  def valid_params(overrides = {})
    { class_code: 'ZONEP', class_name: 'Zone Probe', ticket_type: 'Fixed',
      ticket_price: '10.00', ticketing_fee: '1.00', production_id: production.id }.merge(overrides)
  end

  def nested_params(ticket_class_attrs)
    { theater_id: theater.id, production_id: production.id, ticket_class: ticket_class_attrs }
  end

  describe 'POST #create' do
    # complimentary is rendered by the shared _fields partial but was missing
    # from the permit list, so the checkbox silently kept its column default.
    it 'persists the option flags the shared form renders' do
      post :create, params: nested_params(valid_params(assigns_seats: '1',
                                                       show_in_pricing_range: '0',
                                                       complimentary: '1'))

      ticket_class = production.ticket_classes.find_by(class_code: 'ZONEP')
      expect(ticket_class.assigns_seats).to be true
      expect(ticket_class.show_in_pricing_range).to be false
      expect(ticket_class.complimentary).to be true
    end
  end

  describe 'PATCH #update' do
    it 'persists the option flags the shared form renders' do
      ticket_class = production.ticket_classes.create!(valid_params.except(:production_id))

      patch :update, params: nested_params(valid_params(assigns_seats: '1',
                                                        show_in_pricing_range: '0',
                                                        complimentary: '1')).merge(id: ticket_class.id)

      ticket_class.reload
      expect(ticket_class.assigns_seats).to be true
      expect(ticket_class.show_in_pricing_range).to be false
      expect(ticket_class.complimentary).to be true
    end
  end
end
