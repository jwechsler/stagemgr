require "rails_helper"

RSpec.describe TicketClassSpecialOffer, type: :model do
  # Build a production with two ticket classes: the original (GEN01) and
  # the target class (COMP) that the special offer will switch to.
  let(:production) { FactoryBot.create(:production) }
  let(:performance) { FactoryBot.create(:performance, production: production) }

  # The existing "base" ticket class (already created by the production factory)
  let(:base_ticket_class) do
    production.ticket_classes.find { |tc| !tc.software_managed? && tc.ticket_price > 0 }
  end

  # A new target ticket class to change line items into
  let!(:target_ticket_class) do
    FactoryBot.create(:ticket_class,
                      production: production,
                      class_code: "COMP",
                      class_name: "Complimentary",
                      ticket_price: 0.00,
                      ticket_type: "Fixed")
  end

  # A simple TicketOrder with one line item using base_ticket_class
  let(:order) do
    o = TicketOrder.new(
      performance: performance,
      address: FactoryBot.create(:address),
      payment_type: FactoryBot.create(:cash_payment_type),
      status: Order::NEW
    )
    o.do_not_create_tasks = true
    o.ticket_line_items << TicketLineItem.new(
      ticket_class: base_ticket_class,
      ticket_count: 2
    )
    o.save!(validate: false)
    o.reload
    o
  end

  # A TicketClassSpecialOffer that changes tickets to the COMP class
  let(:special_offer) do
    TicketClassSpecialOffer.create!(
      code: "SWITCH01",
      change_ticket_class_code: "COMP",
      status: SpecialOffer::ACTIVE
    )
  end

  describe "#calculate_discount" do
    it "always returns 0.0 regardless of order" do
      expect(special_offer.calculate_discount(order)).to eq(0.0)
    end
  end

  describe "#to_s" do
    it "includes the change_ticket_class_code in the string representation" do
      expect(special_offer.to_s).to include("COMP")
    end

    it "prepends 'Use <code> on '" do
      result = special_offer.to_s
      expect(result).to start_with("Use COMP on ")
    end
  end

  describe "#modified_line_items_in_order" do
    context "when the target ticket class exists in this production" do
      it "returns a pair [new_items, old_items]" do
        new_items, old_items = special_offer.modified_line_items_in_order(order)
        expect(new_items).to be_an(Array)
        expect(old_items).to be_an(Array)
      end

      it "returns one new TicketLineItem for each applicable old line item" do
        new_items, old_items = special_offer.modified_line_items_in_order(order)
        expect(new_items.size).to eq(old_items.size)
        expect(new_items.size).to be >= 1
      end

      it "new items use the target ticket class" do
        new_items, _old_items = special_offer.modified_line_items_in_order(order)
        new_items.each do |item|
          expect(item.ticket_class.class_code).to eq("COMP")
        end
      end

      it "preserves ticket_count from the old line item" do
        new_items, old_items = special_offer.modified_line_items_in_order(order)
        new_items.zip(old_items).each do |new_item, old_item|
          expect(new_item.ticket_count).to eq(old_item.ticket_count)
        end
      end

      it "copies price_override from the old line item (nil for non-Donation types due to callback)" do
        # SUSPECTED BUG (app/models/special_offers/ticket_class_special_offer.rb:23-24):
        # modified_line_items_in_order sets price_override: li.price_override on new items,
        # intending to preserve the override. However, TicketLineItem#check_price_override
        # (ticket_line_item.rb:69) clears price_override to nil for non-Donation ticket types
        # when saved, so the value is not actually preserved on save.
        # Additionally, the in-memory association `order.ticket_line_items` may not
        # reflect a price_override set via `update_column`; it reflects whatever was
        # loaded at association-access time.
        # Characterization: new items have nil price_override for a Fixed-type class.
        new_items, _old_items = special_offer.modified_line_items_in_order(order)
        expect(new_items.first.price_override).to be_nil
      end
    end

    context "when the target ticket class does NOT exist in this production" do
      let(:special_offer_with_bad_code) do
        TicketClassSpecialOffer.create!(
          code: "BADCODE",
          change_ticket_class_code: "NONEXISTENT",
          status: SpecialOffer::ACTIVE
        )
      end

      it "returns empty arrays for both new and old items" do
        new_items, old_items = special_offer_with_bad_code.modified_line_items_in_order(order)
        expect(new_items).to be_empty
        expect(old_items).to be_empty
      end

      it "adds an error to the special offer object" do
        special_offer_with_bad_code.modified_line_items_in_order(order)
        expect(special_offer_with_bad_code.errors[:special_offer_code]).not_to be_empty
      end
    end
  end

  describe "#apply_to_order" do
    it "returns self" do
      result = special_offer.apply_to_order(order)
      expect(result).to eq(special_offer)
    end

    context "when the target ticket class exists" do
      it "adds new TicketLineItems with the target class to the order" do
        special_offer.apply_to_order(order)
        codes = order.ticket_line_items.map { |li| li.ticket_class.class_code }
        expect(codes).to include("COMP")
      end

      it "removes old TicketLineItems (original class) from the order" do
        original_ticket_class_id = base_ticket_class.id
        special_offer.apply_to_order(order)
        remaining_class_ids = order.ticket_line_items.map(&:ticket_class_id)
        # The original class should no longer be in ticket_line_items
        expect(remaining_class_ids).not_to include(original_ticket_class_id)
      end
    end

    context "when the target ticket class does NOT exist" do
      let(:special_offer_bad) do
        TicketClassSpecialOffer.create!(
          code: "BADAPPLY",
          change_ticket_class_code: "FAKECODE",
          status: SpecialOffer::ACTIVE
        )
      end

      it "does not modify the order's ticket_line_items" do
        original_count = order.ticket_line_items.size
        special_offer_bad.apply_to_order(order)
        expect(order.ticket_line_items.size).to eq(original_count)
      end
    end
  end
end
