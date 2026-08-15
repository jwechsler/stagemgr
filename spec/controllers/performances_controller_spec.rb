require 'rails_helper'

RSpec.describe PerformancesController, type: :controller do
  describe 'GET ticket_classes (json)' do
    let(:production) { FactoryBot.create(:production_with_reserved_seating) }
    let(:performance) do
      FactoryBot.create(:reserved_seating, production: production,
                                           performance_date: Date.today + 1.day,
                                           performance_time: Time.parse('19:00'))
    end

    it 'includes holds_seats so the client can split seat-modal vs picker classes' do
      addon = FactoryBot.create(:ticket_class, production: production, holds_seats: false,
                                               class_name: 'Hearing Assist')
      tca = performance.ticket_class_allocations.find_or_initialize_by(ticket_class: addon)
      tca.available = true
      tca.save!

      get :ticket_classes, params: { id: performance.id }, format: :json
      expect(response).to be_successful
      result = response.parsed_body

      expect(result).not_to be_empty
      expect(result).to all(have_key('holds_seats'))
      addon_row = result.find { |r| r['id'] == addon.id }
      expect(addon_row['holds_seats']).to eq(false)
    end

    # Backend (non-web-visible) classes require BOTH the include_backend param
    # (sent only by the admin box-office page) AND the view_backend_classes
    # ability. The public order flow never sends the param, so even signed-in
    # staff browsing the public page get the customer-facing list.
    describe 'web visibility' do
      let!(:backend_class) do
        tc = FactoryBot.create(:ticket_class, production: production, web_visible: false,
                                              class_name: 'Box Office Comp')
        tca = performance.ticket_class_allocations.find_or_initialize_by(ticket_class: tc)
        tca.available = true
        tca.save!
        tc
      end

      def returned_ids(params = {})
        get :ticket_classes, params: { id: performance.id }.merge(params), format: :json
        expect(response).to be_successful
        response.parsed_body.pluck('id')
      end

      it 'hides non-web-visible classes from anonymous requests' do
        expect(returned_ids).not_to include(backend_class.id)
      end

      it 'hides non-web-visible classes without include_backend, even with the ability' do
        allow(controller).to receive(:current_user).and_return(double('user'))
        allow(controller.current_user).to receive(:can?)
          .with(:view_backend_classes, TicketClassAllocation).and_return(true)

        expect(returned_ids).not_to include(backend_class.id)
      end

      it 'includes non-web-visible classes with include_backend and the ability' do
        allow(controller).to receive(:current_user).and_return(double('user'))
        allow(controller.current_user).to receive(:can?)
          .with(:view_backend_classes, TicketClassAllocation).and_return(true)

        expect(returned_ids(include_backend: '1')).to include(backend_class.id)
      end

      it 'ignores a spoofed include_backend param without the ability' do
        expect(returned_ids(include_backend: '1')).not_to include(backend_class.id)
      end
    end
  end
end
