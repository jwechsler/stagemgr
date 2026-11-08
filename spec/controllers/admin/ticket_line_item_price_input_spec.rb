require 'rails_helper'

# The per-line Price input on the box office ticket order forms
# (admin/application/_ticket_line_item_fields). A line with a ticket class
# shows that class's price; a blank line shows no price, so a post made
# without the page JavaScript never sends a price override of 0.0.
RSpec.describe 'Box office ticket line item price input', type: :controller do
  render_views

  let(:box_office_user) { FactoryBot.create(:user, is_box_office_user: true) }
  let(:original) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }

  before { allow(controller).to receive(:current_user).and_return(box_office_user) }

  def price_inputs
    Nokogiri::HTML(response.body).css('input[name^="ticket_order[ticket_line_items_attributes]"][name$="[price_override]"]')
  end

  describe Admin::ExchangeTicketOrdersController do
    it 'leaves the price blank on the empty line for the new tickets' do
      get :new, params: { ticket_order_id: original.id }

      expect(price_inputs.size).to eq(1)
      expect(price_inputs.first['value'].to_s).to eq('')
    end
  end

  describe Admin::TicketOrdersController do
    it 'leaves the price blank on the empty line Add to Order starts with' do
      get :add_to, params: { id: original.id }

      expect(price_inputs.map { |input| input['value'].to_s }).to eq([''])
    end

    it "shows each existing line's ticket class price" do
      line_item = original.ticket_line_items.first
      original.update_column(:status, Order::HOLD)

      get :edit, params: { id: original.id }

      expect(response).to have_http_status(:ok)
      expect(BigDecimal(price_inputs.first['value'])).to eq(line_item.ticket_class.ticket_price)
    end

    context 'with a donation class line' do
      let(:line_item) { original.ticket_line_items.first }

      before do
        line_item.ticket_class.update_column(:ticket_type, TicketClass::DONATION)
        original.update_column(:status, Order::HOLD)
      end

      it "starts the donation amount at the class's ticket price when the line has no override" do
        line_item.update_column(:price_override, nil)

        get :edit, params: { id: original.id }

        expect(BigDecimal(price_inputs.first['value'])).to eq(line_item.ticket_class.ticket_price)
      end

      it "shows the line's own donation amount when it has an override" do
        line_item.update_column(:price_override, BigDecimal('42.50'))

        get :edit, params: { id: original.id }

        expect(BigDecimal(price_inputs.first['value'])).to eq(BigDecimal('42.50'))
      end
    end
  end
end
