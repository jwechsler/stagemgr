require "rails_helper"

RSpec.describe BuyXGetYSpecialOffer, type: :model do
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

  let(:special_offer) do
    BuyXGetYSpecialOffer.create!(
      code: "B2G1",
      buy_quantity: 2,
      get_quantity: 1,
      ticket_class_code: "GEN",
      status: SpecialOffer::ACTIVE
    )
  end

  def build_order(*line_item_specs)
    o = TicketOrder.new(
      performance: performance,
      address: FactoryBot.create(:address),
      payment_type: FactoryBot.create(:cash_payment_type),
      status: Order::NEW
    )
    o.do_not_create_tasks = true
    line_item_specs.each do |ticket_class, count|
      o.ticket_line_items << TicketLineItem.new(ticket_class: ticket_class, ticket_count: count)
    end
    o.save!(validate: false)
    o.reload
    o
  end

  describe "validations" do
    it "requires positive integer buy and get quantities" do
      expect(BuyXGetYSpecialOffer.new(code: "X", buy_quantity: 2, get_quantity: 1)).to be_valid
      expect(BuyXGetYSpecialOffer.new(code: "X", buy_quantity: nil, get_quantity: 1)).not_to be_valid
      expect(BuyXGetYSpecialOffer.new(code: "X", buy_quantity: 2, get_quantity: 0)).not_to be_valid
      expect(BuyXGetYSpecialOffer.new(code: "X", buy_quantity: -1, get_quantity: 1)).not_to be_valid
      expect(BuyXGetYSpecialOffer.new(code: "X", buy_quantity: 1.5, get_quantity: 1)).not_to be_valid
    end
  end

  describe "#calculate_discount" do
    it "discounts the cheapest qualifying ticket 100% (buy 2 get 1 on 2xGEN40 + GEN30 + GEN20 + PREV10)" do
      order = build_order([gen40, 2], [gen30, 1], [gen20, 1], [prev10, 1])
      expect(order.total_due).to eq(140)
      expect(special_offer.calculate_discount(order)).to eq(-20.0)
      order.build_special_offer_line_item(special_offer: special_offer)
      expect(order.total_due).to eq(120)
    end

    it "frees a ticket inside a multi-count line item" do
      order = build_order([gen40, 2], [gen20, 2])
      expect(special_offer.calculate_discount(order)).to eq(-20.0)
    end

    it "repeats for every full group of X+Y qualifying tickets" do
      order = build_order([gen40, 2], [gen30, 2], [gen20, 2])
      expect(special_offer.calculate_discount(order)).to eq(-40.0)
    end

    it "gives no discount below the buy threshold" do
      order = build_order([gen40, 2])
      expect(special_offer.calculate_discount(order)).to eq(0.0)
    end

    it "ignores tickets that do not match the ticket class prefix" do
      order = build_order([prev10, 4])
      expect(special_offer.calculate_discount(order)).to eq(0.0)

      order = build_order([gen40, 2], [prev10, 1])
      expect(special_offer.calculate_discount(order)).to eq(0.0)
    end

    it "applies to all tickets when no ticket class code is set" do
      offer = BuyXGetYSpecialOffer.create!(code: "B2G1ALL", buy_quantity: 2, get_quantity: 1,
                                           status: SpecialOffer::ACTIVE)
      order = build_order([gen40, 2], [prev10, 1])
      expect(offer.calculate_discount(order)).to eq(-10.0)
    end
  end

  describe "#calculate_royalty_discount" do
    it "mirrors the discount over royalty prices" do
      gen20.update_column(:royalty_amount, 15.00)
      order = build_order([gen40, 2], [gen30, 1], [gen20, 1])
      expect(special_offer.calculate_discount(order)).to eq(-20.0)
      expect(special_offer.calculate_royalty_discount(order)).to eq(-15.0)
    end
  end

  describe "#free_ticket_counts" do
    it "maps the line item containing the free ticket to its free count" do
      order = build_order([gen40, 2], [gen30, 1], [gen20, 1], [prev10, 1])
      gen20_tli = order.ticket_line_items.find { |tli| tli.ticket_class_id == gen20.id }
      expect(special_offer.free_ticket_counts(order)).to eq(gen20_tli.id => 1)
    end

    it "counts only the free portion of a multi-count line item" do
      order = build_order([gen40, 2], [gen20, 2])
      gen20_tli = order.ticket_line_items.find { |tli| tli.ticket_class_id == gen20.id }
      expect(special_offer.free_ticket_counts(order)).to eq(gen20_tli.id => 1)
    end

    it "is empty when no tickets are free" do
      order = build_order([gen40, 2])
      expect(special_offer.free_ticket_counts(order)).to eq({})
    end
  end

  describe "#description" do
    it "includes the quantities and the number of free tickets" do
      order = build_order([gen40, 2], [gen30, 1], [gen20, 1], [prev10, 1])
      expect(special_offer.description(order)).to eq("Buy 2 get 1 free (1 free) on 4 tickets")
    end
  end

  describe "#to_s" do
    it "includes the buy and get quantities" do
      expect(special_offer.to_s).to start_with("Buy 2 get 1 free / ")
    end
  end
end
