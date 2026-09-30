require 'rails_helper'

# The refund page lists what refunding does to each payment; Order#refund!
# returns every refundable payment on its own tender.
RSpec.describe Admin::RefundOrdersController, type: :controller do
  render_views

  let(:box_office_user) { FactoryBot.create(:user, is_box_office_user: true) }
  let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }
  # The real test gateway, spied on: the order page also asks it for links.
  let(:gateway) { PaymentProcessing::BogusGateway.new }

  before do
    allow(controller).to receive(:current_user).and_return(box_office_user)
    allow(PaymentProcessing).to receive(:gateway).and_return(gateway)
    allow(gateway).to receive(:refund).and_call_original
  end

  def add_payment(klass, **attrs)
    klass.create!(order: order, payment_type: FactoryBot.create(:"#{klass.name.underscore}_type"), **attrs)
  end

  describe 'GET new' do
    it 'offers a refund for an order with several payments, one line per payment' do
      add_payment(CashPayment, amount: 20)
      add_payment(CashPayment, amount: 0)

      get :new, params: { order_id: order.id }

      page = Nokogiri::HTML(response.body)
      lines = page.css('#refund-plan li').map { |li| li.text.squish }
      expect(lines).to contain_exactly(
        "bogus ending in 1111: refund #{ActiveSupport::NumberHelper.number_to_currency(order.payments.first.amount)} to the card",
        'Cash: give the patron $20.00 in cash',
        'Cash $0.00: nothing to refund'
      )
      expect(page.at_css('input[type=submit]')['value']).to eq('Process Refund')
      expect(response.body).not_to include('Can only refund orders with only 1 payment')
    end

    it 'refuses an order holding a payment kind the refund cannot return' do
      order.payments << PriceOverridePayment.new(amount: 5, order: order,
                                                 source_payment_type: order.payment_type)

      get :new, params: { order_id: order.id }

      page = Nokogiri::HTML(response.body)
      expect(page.text).to include("Can't refund this order.")
      expect(page.at_css('input[type=submit]')).to be_nil
    end
  end

  describe 'an order paid with exchange credit' do
    before do
      order.payments.first.update_columns(type: 'ExchangePayment')
      order.payments.reload
    end

    it 'is not refundable, and the page points to Exchange and Refund' do
      get :new, params: { order_id: order.id }

      page = Nokogiri::HTML(response.body)
      expect(order.reload).not_to be_refundable
      expect(page.text).to include('paid with exchange credit')
      expect(page.at_css('input[type=submit]')).to be_nil
    end

    it 'refuses a refund posted anyway' do
      post :create, params: { order_id: order.id }

      expect(flash[:error]).to include("can't be refunded here")
      expect(order.reload.status).to eq(Order::PROCESSED)
      expect(gateway).not_to have_received(:refund)
    end
  end

  describe 'POST create' do
    it 'refunds the card and the cash payment each on its own tender' do
      card = order.payments.first
      add_payment(CashPayment, amount: 20)

      post :create, params: { order_id: order.id, order: { notes: 'Patron cancelled' } }

      order.reload
      expect(gateway).to have_received(:refund).once.with((card.amount * 100).round, 'TEST_TRANSACTION', anything)
      expect(order.status).to eq(Order::REFUNDED)
      expect(order.payments.grep(CashPayment).map(&:amount)).to contain_exactly(20, -20)
      expect(order.total_paid).to eq(0)
    end
  end
end
