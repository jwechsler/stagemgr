require 'rails_helper'

RSpec.describe FlexPassOrder, type: :model do
  describe "#cancel!" do
    let(:theater) { FactoryBot.create(:theater) }
    let(:flex_pass_offer) { FactoryBot.create(:flex_pass_offer, theater: theater, number_of_tickets: 10) }
    let(:address) { FactoryBot.create(:address) }
    let(:flex_pass_order) { FactoryBot.create(:flex_pass_order, :with_payment, address: address, flex_pass_offer: flex_pass_offer) }
    let(:flex_pass) { flex_pass_order.flex_pass }

    context "when flex pass has upcoming ticket orders" do
      before do
        # Create a future performance and ticket order
        production = FactoryBot.create(:production, theater: theater)
        performance = FactoryBot.create(:performance, production: production, performance_date: 1.week.from_now)
        ticket_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance, address: address, status: Order::PROCESSED)
        
        # Create a flex pass payment for the ticket order
        FactoryBot.create(:flex_pass_payment, order: ticket_order, flex_pass: flex_pass, number_of_tickets: 2)
      end

      it "does not cancel the order" do
        result = flex_pass_order.cancel!
        expect(result).to be false
      end

      it "adds an error message" do
        flex_pass_order.cancel!
        expect(flex_pass_order.errors[:error]).to include("Cannot cancel a flex_pass with upcoming ticket orders")
      end

      it "does not change the order status" do
        expect { flex_pass_order.cancel! }.not_to change { flex_pass_order.status }
      end

      it "does not deactivate the flex pass" do
        expect { flex_pass_order.cancel! }.not_to change { flex_pass.reload.active? }
      end
    end

    context "when flex pass has NO redemptions" do
      it "cancels the order successfully" do
        result = flex_pass_order.cancel!
        expect(result).to be true
      end

      it "refunds the order" do
        expect(flex_pass_order).to receive(:refund!)
        flex_pass_order.cancel!
      end

      it "deletes the flex pass" do
        flex_pass_id = flex_pass.id
        flex_pass_order.cancel!
        expect(FlexPass.find_by(id: flex_pass_id)).to be_nil
      end

      it "sets the order status to REFUNDED" do
        flex_pass_order.cancel!
        expect(flex_pass_order.reload.status).to eq(Order::REFUNDED)
      end

      it "adds an info message about refund and deletion" do
        flex_pass_code = flex_pass.code
        flex_pass_order.cancel!
        expect(flex_pass_order.errors[:info]).to include("Flex Pass #{flex_pass_code} has been refunded and deleted")
      end
    end

    context "when flex pass has past redemptions but no upcoming orders" do
      before do
        # Create a past performance and ticket order
        production = FactoryBot.create(:production, theater: theater)
        performance = FactoryBot.create(:performance, production: production, performance_date: 1.week.ago)
        ticket_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance, address: address, status: Order::FULFILLED)
        
        # Create a flex pass payment for the ticket order
        FactoryBot.create(:flex_pass_payment, order: ticket_order, flex_pass: flex_pass, number_of_tickets: 2)
      end

      it "cancels the order successfully" do
        result = flex_pass_order.cancel!
        expect(result).to be true
      end

      it "does NOT refund the order" do
        expect(flex_pass_order).not_to receive(:refund!)
        flex_pass_order.cancel!
      end

      it "does NOT delete the flex pass" do
        flex_pass_id = flex_pass.id
        flex_pass_order.cancel!
        expect(FlexPass.find_by(id: flex_pass_id)).not_to be_nil
      end

      it "deactivates the flex pass" do
        flex_pass_order.cancel!
        expect(flex_pass.reload.active?).to be false
      end

      it "does NOT change the order status" do
        original_status = flex_pass_order.status
        flex_pass_order.cancel!
        expect(flex_pass_order.reload.status).to eq(original_status)
      end

      it "adds an info message about deactivation" do
        flex_pass_code = flex_pass.code
        flex_pass_order.cancel!
        expect(flex_pass_order.errors[:info]).to include("Flex Pass #{flex_pass_code} inactive")
      end
    end

    context "when an error occurs during cancellation" do
      before do
        # Mock the refund! method to raise an error
        allow(flex_pass_order).to receive(:refund!).and_raise(ActiveRecord::RecordInvalid)
      end

      it "rolls back the transaction" do
        expect { flex_pass_order.cancel! rescue nil }.not_to change { flex_pass_order.reload.status }
      end

      it "does not delete the flex pass" do
        flex_pass_id = flex_pass.id
        flex_pass_order.cancel! rescue nil
        expect(FlexPass.find_by(id: flex_pass_id)).not_to be_nil
      end

      it "raises the error" do
        expect { flex_pass_order.cancel! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end