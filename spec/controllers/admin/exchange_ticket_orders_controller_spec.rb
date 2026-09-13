require 'rails_helper'

RSpec.describe Admin::ExchangeTicketOrdersController, type: :controller do
  let(:box_office_user) { FactoryBot.create(:user, is_box_office_user: true) }
  let(:theater_user)    { FactoryBot.create(:user) }
  let(:original)        { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }
  let(:exchange_order)  { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets) }

  let(:exchange_params) do
    { ticket_order_id: original.id,
      ticket_order: { performance_code: original.performance.performance_code, payment_type_id: original.payment_type_id } }
  end

  before do
    allow(controller).to receive(:build_exchange_order).and_return(exchange_order)
    allow(exchange_order).to receive(:exchange_and_process_from!)
    allow(exchange_order).to receive(:exchange_and_refund_from!)
  end

  describe 'POST #create as box office' do
    before { allow(controller).to receive(:current_user).and_return(box_office_user) }

    it 'runs a plain exchange when the Exchange Order button is used' do
      post :create, params: exchange_params.merge(commit: 'Exchange Order')

      expect(exchange_order).to have_received(:exchange_and_process_from!).with(original)
      expect(exchange_order).not_to have_received(:exchange_and_refund_from!)
      expect(response).to redirect_to(admin_ticket_order_path(exchange_order))
      expect(flash[:notice]).to eq('Order was successfully exchanged.')
    end

    it 'runs an exchange-and-refund when the red button is used' do
      post :create, params: exchange_params.merge(exchange_and_refund: 'Exchange and Refund')

      expect(exchange_order).to have_received(:exchange_and_refund_from!).with(original)
      expect(exchange_order).not_to have_received(:exchange_and_process_from!)
      expect(response).to redirect_to(admin_ticket_order_path(exchange_order))
    end

    it 'explains a declined refund and returns to the original order' do
      allow(exchange_order).to receive(:exchange_and_refund_from!).and_raise(CannotProcessPayment, 'card_declined')

      post :create, params: exchange_params.merge(exchange_and_refund: 'Exchange and Refund')

      expect(response).to redirect_to(admin_ticket_order_path(original))
      expect(flash[:error]).to eq('Refund could not be processed: card_declined')
    end

    it 'explains when there is nothing to refund' do
      allow(exchange_order).to receive(:exchange_and_refund_from!)
        .and_raise(ExchangeRefundable::RefundNotPossible, 'Nothing to refund')

      post :create, params: exchange_params.merge(exchange_and_refund: 'Exchange and Refund')

      expect(response).to redirect_to(admin_ticket_order_path(original))
      expect(flash[:error]).to eq('Refund could not be processed: Nothing to refund')
    end

    it 'reports other exchange failures with the generic message' do
      allow(exchange_order).to receive(:exchange_and_process_from!).and_raise(ActiveRecord::RecordInvalid)

      post :create, params: exchange_params.merge(commit: 'Exchange Order')

      expect(response).to redirect_to(admin_ticket_order_path(original))
      expect(flash[:error]).to start_with('There was a problem with the exchange.')
    end
  end

  describe 'POST #create as a theater user' do
    before { allow(controller).to receive(:current_user).and_return(theater_user) }

    it 'denies the refund path before touching the order' do
      post :create, params: exchange_params.merge(exchange_and_refund: 'Exchange and Refund')

      expect(exchange_order).not_to have_received(:exchange_and_refund_from!)
      expect(exchange_order).not_to have_received(:exchange_and_process_from!)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('You are not authorized to access this page.')
    end
  end

  describe 'GET #new' do
    render_views

    it 'offers both buttons to box office users' do
      allow(controller).to receive(:current_user).and_return(box_office_user)

      get :new, params: { ticket_order_id: original.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="Exchange Order"')
      expect(response.body).to include('name="exchange_and_refund"')
      expect(response.body).not_to include('Place Order')
    end

    it 'hides the refund button from theater users' do
      allow(controller).to receive(:current_user).and_return(theater_user)

      get :new, params: { ticket_order_id: original.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="Exchange Order"')
      expect(response.body).not_to include('exchange_and_refund')
    end
  end
end
