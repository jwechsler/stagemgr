require 'rails_helper'

# The fixes on the review banner of an order flagged after a refund made in
# the Stripe dashboard. Box office and admins only, like Exchange.
RSpec.describe Admin::OrderReviewsController, type: :controller do
  let(:box_office_user) { FactoryBot.create(:user, is_box_office_user: true) }
  let(:theater_user) { FactoryBot.create(:user) }
  let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }
  let(:card) { order.payments.grep(CreditCardPayment).first }
  let(:gateway) { PaymentProcessing::BogusGateway.new }

  before do
    allow(PaymentProcessing).to receive(:gateway).and_return(gateway)
    allow(gateway).to receive(:refund).and_call_original
    allow(controller).to receive(:current_user).and_return(box_office_user)
  end

  def refund_in_stripe(amount)
    RefundPayment.create!(order: order, source_payment: card, payment_type: card.payment_type, amount: -amount,
                          stripe_refund_id: "re_#{SecureRandom.hex(4)}")
    order.flag_for_review!('Stripe refund')
  end

  it 'resolves with the note and the user who acknowledged it' do
    refund_in_stripe(5)

    post :resolve, params: { order_id: order.id, review_note: 'Manager approved the partial refund' }

    expect(response).to redirect_to(admin_order_path(order))
    expect(order.reload).to have_attributes(needs_review?: false, reviewed_by_id: box_office_user.id,
                                            review_note: 'Manager approved the partial refund')
    expect(order.total_due).not_to eq(order.total_paid)
  end

  it 'applies the shortfall as a discount' do
    refund_in_stripe(5)

    post :discount, params: { order_id: order.id, review_note: '' }

    order.reload
    expect(order.total_due).to eq(order.total_paid)
    expect(order).not_to be_needs_review
    expect(flash[:notice]).to include('discount')
  end

  it 'marks an order refunded in full in Stripe as refunded without refunding the card again' do
    refund_in_stripe(card.amount)

    post :mark_refunded, params: { order_id: order.id }

    expect(gateway).not_to have_received(:refund)
    expect(order.reload.status).to eq(Order::REFUNDED)
  end

  it 'explains a fix that no longer applies' do
    refund_in_stripe(5)

    post :mark_refunded, params: { order_id: order.id }

    expect(flash[:error]).to eq("Couldn't resolve the review: The card is not fully refunded in Stripe.")
    expect(order.reload).to be_needs_review
  end

  it 'is refused to theater staff' do
    allow(controller).to receive(:current_user).and_return(theater_user)
    refund_in_stripe(5)

    post :resolve, params: { order_id: order.id }

    expect(order.reload).to be_needs_review
  end
end

# The banner on the order page: the live balance and the fixes.
RSpec.describe Admin::TicketOrdersController, 'review banner', type: :controller do
  render_views

  let(:box_office_user) { FactoryBot.create(:user, is_box_office_user: true) }
  let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }
  let(:card) { order.payments.grep(CreditCardPayment).first }

  before do
    allow(controller).to receive(:current_user).and_return(box_office_user)
    allow(PaymentProcessing).to receive(:gateway).and_return(PaymentProcessing::BogusGateway.new)
  end

  def banner
    Nokogiri::HTML(response.body).at_css('#review-banner')
  end

  it 'shows no banner on an order that needs no review' do
    get :show, params: { id: order.id }

    expect(banner).to be_nil
  end

  it 'shows the reason, the balance and the fixes, escaping the reason' do
    RefundPayment.create!(order: order, source_payment: card, payment_type: card.payment_type, amount: -5)
    order.flag_for_review!('Stripe refund $5.00 <b>on</b> 10/02')
    due = ActiveSupport::NumberHelper.number_to_currency(order.total_due)
    paid = ActiveSupport::NumberHelper.number_to_currency(order.reload.total_paid)

    get :show, params: { id: order.id }

    expect(banner.at_css('#review-reason').text).to eq('Stripe refund $5.00 <b>on</b> 10/02')
    expect(banner.at_css('#review-balance').text.squish).to eq("Order is $5.00 out of balance (due #{due}, paid #{paid}).")
    expect(banner.at_css('#review-discount')).to be_present
    expect(banner.at_css('#review-acknowledge')).to be_present
    expect(banner.at_css('#review-mark-refunded')).to be_nil
  end
end
