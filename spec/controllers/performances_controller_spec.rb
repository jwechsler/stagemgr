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

    # ResourcedTicketClass shadow rows: exhausted (pool == 0) means "not for
    # sale" regardless of the per-performance allocation, and every resourced
    # row carries a remaining count so box-office JS can cap quantity.
    describe 'resourced ticket classes' do
      let(:resource) do
        FactoryBot.create(:resourced_ticket_class, quantity: 1, venues: [production.venue])
      end

      let!(:shadow) do
        tc = TicketClass.find_or_initialize_by(production_id: production.id,
                                               resourced_ticket_class_id: resource.id)
        tc.synced_from_resource = true
        tc.attributes = resource.shadow_attributes
        tc.save!
        tc
      end

      before do
        tca = TicketClassAllocation.find_or_create_by!(performance: performance, ticket_class: shadow)
        tca.update!(available: true)
        performance.ticket_class_allocations.reload
      end

      def resourced_row
        get :ticket_classes, params: { id: performance.id }, format: :json
        response.parsed_body.find { |r| r['id'] == shadow.id }
      end

      it 'reports the remaining pool count for a resourced class' do
        row = resourced_row
        expect(row).to be_present
        expect(row['remaining']).to eq(1)
      end

      it 'reports nil remaining for a non-resourced class' do
        addon = FactoryBot.create(:ticket_class, production: production, holds_seats: false,
                                                 class_name: 'Hearing Assist')
        tca = performance.ticket_class_allocations.find_or_initialize_by(ticket_class: addon)
        tca.available = true
        tca.save!

        get :ticket_classes, params: { id: performance.id }, format: :json
        row = response.parsed_body.find { |r| r['id'] == addon.id }

        expect(row['remaining']).to be_nil
      end

      it 'omits an exhausted resourced class from the response entirely' do
        order = TicketOrder.new(status: Order::PROCESSED, performance: performance,
                                address: FactoryBot.create(:address),
                                payment_type: FactoryBot.create(:cash_payment_type))
        order.ticket_line_items << TicketLineItem.new(ticket_class: shadow, ticket_count: 1)
        order.save!

        row = resourced_row
        expect(row).to be_nil
      end
    end
  end
end
