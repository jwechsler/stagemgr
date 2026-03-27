require 'rails_helper'
require 'stripe_mock'

RSpec.describe "converting a ticket order to a donation" do
  before { StripeMock.start }
  after  { StripeMock.stop }

  def create_convertible_order(*traits)
    order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, *traits)
    order.theater.update!(accepts_donations: true)
    order.reload
    order
  end

  describe "#convertible_to_donation?" do
    it "returns true for a processed cash order with a 501(c)(3) theater" do
      order = create_convertible_order
      expect(order.convertible_to_donation?).to be true
    end

    it "returns true for a fulfilled cash order" do
      order = create_convertible_order
      order.transition_to!(Order::FULFILLED)
      expect(order.convertible_to_donation?).to be true
    end

    it "returns false when paid with flex pass" do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_flex_pass)
      order.theater.update!(accepts_donations: true)
      order.reload
      expect(order.convertible_to_donation?).to be false
    end

    it "returns false when paid with membership" do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_membership)
      order.theater.update!(accepts_donations: true)
      order.reload
      expect(order.convertible_to_donation?).to be false
    end

    it "returns false when theater does not accept donations" do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
      order.theater.update!(accepts_donations: false)
      order.reload
      expect(order.convertible_to_donation?).to be false
    end

    it "returns false for a held order" do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets)
      order.theater.update!(accepts_donations: true)
      order.reload
      expect(order.convertible_to_donation?).to be false
    end

    it "returns false for a refunded order" do
      order = create_convertible_order
      order.refund!
      expect(order.convertible_to_donation?).to be false
    end
  end

  describe "#convert_to_donation!" do
    it "raises if order is not convertible" do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
      order.theater.update!(accepts_donations: false)
      order.reload
      expect { order.convert_to_donation! }.to raise_error("Order is not convertible to a donation")
    end

    context "with a convertible order" do
      let(:order) { create_convertible_order }
      let(:original_amount) { order.total_paid }
      let!(:donation) { order.convert_to_donation! }

      it "returns a DonationOrder" do
        expect(donation).to be_a(DonationOrder)
      end

      it "creates the donation as PROCESSED" do
        expect(donation.status).to eq(Order::PROCESSED)
      end

      it "sets donation amount to the original total paid" do
        expect(donation.total).to eq(original_amount)
      end

      it "assigns the same address to the donation" do
        expect(donation.address).to eq(order.address)
      end

      it "assigns the same payment_type to the donation" do
        expect(donation.payment_type).to eq(order.payment_type)
      end

      it "assigns the same theater to the donation" do
        expect(donation.theater).to eq(order.theater)
      end

      it "sets campaign to the production name" do
        expect(donation.campaign).to eq(order.performance.production.name)
      end

      it "moves all payments to the donation order" do
        donation.reload
        expect(donation.payments.count).to be > 0
        expect(donation.total_paid).to eq(original_amount)
      end

      it "leaves no payments on the original order" do
        order.reload
        expect(order.payments.count).to eq(0)
      end

      it "cancels the original order" do
        order.reload
        expect(order.status).to eq(Order::CANCELED)
      end

      it "destroys all ticket line items on the original order" do
        order.reload
        expect(order.ticket_line_items.count).to eq(0)
      end

      it "appends a note referencing the donation order" do
        order.reload
        expect(order.notes).to include("Converted to Donation Order ##{donation.id}")
      end
    end

    context "with a reserved seating order" do
      let(:order) do
        o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, :reserved_seating)
        o.theater.update!(accepts_donations: true)
        o.reload
        o
      end

      it "unassigns all seats after conversion" do
        order_uuid = order.uuid
        order.convert_to_donation!
        assigned = SeatAssignment.where(order_uuid: order_uuid)
        expect(assigned.count).to eq(0)
      end
    end
  end
end
