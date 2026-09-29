require 'rails_helper'

# Add to Order through the normal box-office order page: GET add_to renders the
# order form for a new addition; the normal create action places it and, once
# it has merged (and been deleted), returns staff to the order it was added to.
RSpec.describe Admin::TicketOrdersController, 'Add to Order', type: :controller do
  render_views

  let(:box_office_user) { FactoryBot.create(:user, is_box_office_user: true) }
  let(:theater_user)    { FactoryBot.create(:user) }
  let(:production) { FactoryBot.create(:production, capacity: 20) }
  let(:performance) do
    FactoryBot.create(:general_admission, production: production, performance_date: Date.current + 7.days,
                                          performance_time: Time.parse('19:00'))
  end
  let(:target) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card, performance: performance) }
  let(:cash) { FactoryBot.create(:cash_payment_type) }
  let(:tablet) do
    tc = FactoryBot.create(:ticket_class, production: production, holds_seats: false, ticket_price: 5,
                                          class_code: "TAB#{SecureRandom.hex(3).upcase}", class_name: 'Captioning tablet')
    FactoryBot.create(:ticket_class_allocation, performance: performance, ticket_class: tc)
    performance.ticket_class_allocations.reload
    tc
  end

  before do
    allow(Resque).to receive(:enqueue)
    allow_any_instance_of(TicketOrder).to receive(:resend_confirmation!)
  end

  def place_params(send_confirmation: '1', **order_attrs)
    { submit_action: 'Place Order', uuid: SecureRandom.uuid, send_confirmation: send_confirmation,
      ticket_order: { merge_target_id: target.id, performance_code: performance.performance_code,
                      payment_type_id: cash.id,
                      address_attributes: { full_name: target.address.full_name, email: target.address.email },
                      ticket_line_items_attributes: { '0' => { ticket_class_id: tablet.id, ticket_count: 1 } } }
                    .merge(order_attrs) }
  end

  describe 'as box office' do
    before { allow(controller).to receive(:current_user).and_return(box_office_user) }

    it 'renders the normal order page for a new addition to the order' do
      tablet
      get :add_to, params: { id: target.id }

      page = Nokogiri::HTML(response.body)
      expect(response).to be_successful
      expect(page.at_css('#addition-banner').text.squish).to include("Adding to order ##{target.id}")
      expect(page.at_css('input#ticket_order_merge_target_id')['value']).to eq(target.id.to_s)
      expect(page.at_css('#send_confirmation')['checked']).to eq('checked')
      expect(page.at_css('#ticket_order_special_offer_code')).to be_nil
    end

    it "offers the payment types the order's performance allows, hiding its restricted ones" do
      %i[credit_card_payment_type cash_payment_type check_payment_type external_payment_type
         membership_payment_type flex_pass_payment_type].each { |type| FactoryBot.create(type) }
      PaymentRestriction.create!(performance: performance, payment_type: FlexPassPaymentType.first)

      get :add_to, params: { id: target.id }

      offered = Nokogiri::HTML(response.body).css('#ticket_order_payment_type_id option').map(&:text)
      expect(offered).to match_array(['Credit Card', 'Cash', 'Check', 'External Payment', 'Membership'])
    end

    it 'sends staff back to a fulfilled order, which cannot be added to' do
      target.update_column(:status, Order::FULFILLED)

      get :add_to, params: { id: target.id }

      expect(response).to redirect_to(admin_ticket_order_path(target))
      expect(flash[:error]).to include("can't be added to")
    end

    it 'places the addition, merges it, leaves no addition row and returns to the order' do
      params = place_params

      expect { post :create, params: params }.not_to change(TicketOrder, :count)
      expect(TicketOrder.where(uuid: params[:uuid])).not_to exist
      expect(response).to redirect_to(admin_ticket_order_path(target))
      expect(flash[:notice]).to eq("Added to order ##{target.id}.")
      expect(target.ticket_line_items.reload.map(&:ticket_class)).to include(tablet)
    end

    it 'passes an unticked confirmation box on to the merge' do
      expect_any_instance_of(TicketOrder).not_to receive(:resend_confirmation!)

      post :create, params: place_params(send_confirmation: '0')

      expect(response).to redirect_to(admin_ticket_order_path(target))
      expect(target.ticket_line_items.reload.map(&:ticket_class)).to include(tablet)
    end

    it 'queues the house-count refresh and one updated confirmation after the merge commits' do
      target
      expect(Resque).to receive(:enqueue).with(CalculateHouseCountsJob, performance.id).once
      expect_any_instance_of(TicketOrder).to receive(:resend_confirmation!).once

      post :create, params: place_params

      expect(response).to redirect_to(admin_ticket_order_path(target))
    end

    it 'adds a GA add-on and an extra seat through the regular ticket list' do
      seat_class = target.ticket_line_items.first.ticket_class
      post :create, params: place_params(ticket_line_items_attributes: {
                                           '0' => { ticket_class_id: tablet.id, ticket_count: 1 },
                                           '1' => { ticket_class_id: seat_class.id, ticket_count: 1 }
                                         })

      expect(response).to redirect_to(admin_ticket_order_path(target))
      counts = target.ticket_line_items.reload.group_by(&:ticket_class).transform_values { |i| i.sum(&:ticket_count) }
      expect(counts[tablet]).to eq(1)
      expect(counts[seat_class]).to eq(3)
      target.reload
      expect(target.total_due).to eq(target.total_paid)
    end

    it 'offers non-seat classes in the GA ticket-class lookup' do
      tablet
      get :autocomplete_ticket_line_item_ticket_class_code,
          params: { performance_code: performance.performance_code, term: tablet.class_code[0, 3] }

      expect(response.parsed_body.pluck('id')).to include(tablet.id)
    end

    it "uses the order's own address record, whatever the form sends" do
      target
      expect do
        post :create, params: place_params(address_attributes: { full_name: 'Someone Else', email: 'x@example.com' })
      end.not_to change(Address, :count)

      expect(response).to redirect_to(admin_ticket_order_path(target))
      expect(target.address.reload.full_name).not_to eq('Someone Else')
    end

    # Without views: the order form for a rolled-back record needs the real
    # (non-savepoint) rollback of production to be a new record again; test
    # transactions only roll back to a savepoint, which keeps AR's saved state.
    describe 'a declined card' do
      render_views false

      it 'leaves no addition, re-shows the page with the error and frees held seats' do
        gateway = double('gateway')
        allow(PaymentProcessing).to receive(:gateway).and_return(gateway)
        allow(gateway).to receive(:purchase)
          .and_return(double('response', success?: false, authorization: nil, params: {}, message: 'Card declined'))
        expect(TicketOrderAddition).to receive(:release_holds).and_call_original
        params = place_params(payment_type_id: FactoryBot.create(:credit_card_payment_type).id,
                              credit_card_type: 'Visa', credit_card_number: '4111111111111111',
                              credit_card_expiration_month: '12',
                              credit_card_expiration_year: (Date.current.year + 2).to_s,
                              credit_card_verification_number: '123')

        post :create, params: params

        expect(response).to have_http_status(:ok)
        expect(response).to render_template('edit')
        expect(flash[:error]).to include('Card declined')
        expect(TicketOrder.where(uuid: params[:uuid])).not_to exist
      end
    end

    it 'refuses the two-step Assign Seats for an addition' do
      params = place_params.merge(submit_action: 'Assign Seats')
      post :create, params: params

      expect(response.body).to include('An addition is placed in one step')
      expect(TicketOrder.where(uuid: params[:uuid])).not_to exist
    end

    it 'refuses a discount code on the addition' do
      params = place_params(special_offer_code: 'HALFOFF')
      post :create, params: params

      expect(response.body).to include('Special offers and discount codes do not apply')
      expect(TicketOrder.where(uuid: params[:uuid])).not_to exist
    end

    it 'never turns an existing order into an addition on update' do
      other = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card, performance: performance)

      patch :update, params: { id: other.id, ticket_order: { merge_target_id: target.id, notes: 'Late arrival' } }

      expect(controller.instance_variable_get(:@ticket_order)).not_to be_addition
      expect(other.reload.notes).to eq('Late arrival')
    end
  end

  describe 'as a theater user' do
    before { allow(controller).to receive(:current_user).and_return(theater_user) }

    it 'may not open Add to Order' do
      get :add_to, params: { id: target.id }

      expect(response).to redirect_to(root_path)
    end

    it 'may not create an addition through the order form' do
      params = place_params
      post :create, params: params

      expect(response).to redirect_to(root_path)
      expect(TicketOrder.where(uuid: params[:uuid])).to be_empty
    end
  end
end
