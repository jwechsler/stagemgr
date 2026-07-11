require "rails_helper"

RSpec.describe "ticket_orders/confirm.html.haml", type: :view do
  let(:production) { FactoryBot.create(:production) }
  let(:performance) { FactoryBot.create(:performance, production: production) }

  let!(:gen40) do
    FactoryBot.create(:ticket_class, production: production, class_code: "GEN40",
                                     class_name: "General 40", ticket_price: 40.00)
  end
  let!(:gen30) do
    FactoryBot.create(:ticket_class, production: production, class_code: "GEN30",
                                     class_name: "General 30", ticket_price: 30.00)
  end
  let!(:gen20) do
    FactoryBot.create(:ticket_class, production: production, class_code: "GEN20",
                                     class_name: "General 20", ticket_price: 20.00)
  end
  let!(:prev10) do
    FactoryBot.create(:ticket_class, production: production, class_code: "PREV10",
                                     class_name: "Preview 10", ticket_price: 10.00)
  end

  let(:offer) do
    BuyXGetYSpecialOffer.create!(code: "B2G1", buy_quantity: 2, get_quantity: 1,
                                 ticket_class_code: "GEN", status: SpecialOffer::ACTIVE)
  end

  let(:order) do
    o = TicketOrder.new(
      performance: performance,
      address: FactoryBot.create(:address),
      payment_type: FactoryBot.create(:cash_payment_type),
      status: Order::NEW
    )
    o.do_not_create_tasks = true
    o.ticket_line_items << TicketLineItem.new(ticket_class: gen40, ticket_count: 2)
    o.ticket_line_items << TicketLineItem.new(ticket_class: gen30, ticket_count: 1)
    o.ticket_line_items << TicketLineItem.new(ticket_class: gen20, ticket_count: 1)
    o.ticket_line_items << TicketLineItem.new(ticket_class: prev10, ticket_count: 1)
    o.save!(validate: false)
    o.reload
    o
  end

  it "marks the free ticket and totals $120 for the user's example order" do
    order.build_special_offer_line_item(special_offer: offer)
    assign(:ticket_order, order)
    render

    expect(rendered).to include("FREE with offer B2G1")
    expect(rendered).to include("General 20")
    expect(rendered).to include("$120.00")
    expect(rendered).not_to include("$140.00")
    # paid rows intact
    expect(rendered).to include("$80.00") # 2 x GEN40
    expect(rendered).to include("$30.00")
    expect(rendered).to include("$10.00")
  end

  it "renders unchanged without a special offer" do
    assign(:ticket_order, order)
    render

    expect(rendered).not_to include("FREE with offer")
    expect(rendered).to include("$140.00")
  end
end
