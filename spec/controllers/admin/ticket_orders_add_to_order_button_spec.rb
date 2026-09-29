require 'rails_helper'

# The Add to Order button on the admin order page (see TicketOrderAddition.addable?).
RSpec.describe Admin::TicketOrdersController, 'Add to Order button', type: :controller do
  render_views

  let(:box_office_user) { FactoryBot.create(:user, is_box_office_user: true) }
  let(:performance) do
    FactoryBot.create(:general_admission, performance_date: Date.current + 7.days,
                                          performance_time: Time.parse('19:00'))
  end
  let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card, performance: performance) }

  before { allow(controller).to receive(:current_user).and_return(box_office_user) }

  def add_to_order_button
    Nokogiri::HTML(response.body).at_css('#add-to-order-button')
  end

  it 'offers Add to Order on a sold order for an upcoming performance' do
    get :show, params: { id: order.id }

    expect(add_to_order_button['href']).to eq(add_to_admin_ticket_order_path(order))
  end

  it 'hides Add to Order on a fulfilled order (the patron buys a separate order)' do
    order.update_column(:status, Order::FULFILLED)

    get :show, params: { id: order.id }

    expect(add_to_order_button).to be_nil
  end

  it 'hides Add to Order while an exchange is replacing the order' do
    exchange = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance)
    exchange.update_columns(status: Order::EXCHANGING, exchange_source_id: order.id)

    get :show, params: { id: order.id }

    expect(add_to_order_button).to be_nil
  end

  it 'still offers Add to Order on a processed order after its performance' do
    performance.update_columns(performance_date: Date.current - 1.day)

    get :show, params: { id: order.id }

    expect(add_to_order_button).not_to be_nil
  end
end
