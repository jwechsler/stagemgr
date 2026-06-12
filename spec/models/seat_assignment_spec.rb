require 'rails_helper'

RSpec.describe SeatAssignment, type: :model do
  describe ".release_temporary_holds_for_performance" do
    let(:production) { FactoryBot.create(:production_with_reserved_seating) }
    let(:performance1) {
      FactoryBot.create(:reserved_seating, production: production, performance_date: Date.today + 1.day,
                                           performance_time: Time.parse("19:00"))
    }
    let(:performance2) {
      FactoryBot.create(:reserved_seating, production: production, performance_date: Date.today + 2.days,
                                           performance_time: Time.parse("19:00"))
    }
    let(:seat_map) { performance1.production.seat_map }

    before do
      # Ensure performances have seat assignments
      SeatAssignment.available_seat_assignments(performance1)
      SeatAssignment.available_seat_assignments(performance2)
    end

    context "when there are TEMPORARY seats without orders" do
      before do
        # Create TEMPORARY seats without orders (orphaned holds)
        @orphaned_seats = performance1.seat_assignments.take(3)
        @orphaned_seats.each do |sa|
          sa.update!(status: SeatAssignment::TEMPORARY, order_uuid: nil, accessibility: 'wheelchair')
        end
      end

      it "releases the orphaned TEMPORARY seats" do
        count = SeatAssignment.release_temporary_holds_for_performance(performance1.id)

        expect(count).to eq(3)
        @orphaned_seats.each do |sa|
          sa.reload
          expect(sa.status).to eq(SeatAssignment::AVAILABLE)
          expect(sa.order_uuid).to be_nil
          expect(sa.accessibility).to be_nil
        end
      end
    end

    context "when there are TEMPORARY seats with valid orders in HOLDING_SEAT_STATUSES" do
      before do
        # Create a simple order and manually assign seats
        ticket_class = performance1.ticket_class_allocations.first.ticket_class
        @ticket_order = TicketOrder.new(
          status: Order::HOLD,
          performance: performance1,
          address: FactoryBot.create(:address),
          payment_type: FactoryBot.create(:cash_payment_type)
        )
        @ticket_order.ticket_line_items << FactoryBot.build(:ticket_line_item,
                                                            ticket_class: ticket_class,
                                                            ticket_count: 2,
                                                            order: @ticket_order)

        # Manually assign seats to this order with TEMPORARY status
        @held_seats = performance1.seat_assignments.where(status: SeatAssignment::AVAILABLE).take(2)
        @held_seats.each do |sa|
          sa.update!(status: SeatAssignment::TEMPORARY, order_uuid: @ticket_order.uuid)
          @ticket_order.seats << sa
        end
        @ticket_order.save!

        # Ensure seats remain TEMPORARY (save! might have changed them to ASSIGNED)
        @held_seats.each do |sa|
          sa.reload
          sa.update!(status: SeatAssignment::TEMPORARY) unless sa.status == SeatAssignment::TEMPORARY
        end
      end

      it "does NOT release seats associated with valid holding orders" do
        count = SeatAssignment.release_temporary_holds_for_performance(performance1.id)

        expect(count).to eq(0)
        @held_seats.each do |sa|
          sa.reload
          expect(sa.status).to eq(SeatAssignment::TEMPORARY)
          expect(sa.order_uuid).to eq(@ticket_order.uuid)
        end
      end
    end

    context "when there are TEMPORARY seats with orders in non-holding statuses" do
      before do
        # Create a simple order with CANCELED status
        ticket_class = performance1.ticket_class_allocations.first.ticket_class
        @canceled_order = TicketOrder.new(
          status: Order::CANCELED,
          performance: performance1,
          address: FactoryBot.create(:address),
          payment_type: FactoryBot.create(:cash_payment_type)
        )
        @canceled_order.ticket_line_items << FactoryBot.build(:ticket_line_item,
                                                              ticket_class: ticket_class,
                                                              ticket_count: 2,
                                                              order: @canceled_order)

        # Create TEMPORARY seats pointing to the canceled order
        @abandoned_seats = performance1.seat_assignments.where(status: SeatAssignment::AVAILABLE).take(2)
        @abandoned_seats.each do |sa|
          sa.update!(status: SeatAssignment::TEMPORARY, order_uuid: @canceled_order.uuid)
          @canceled_order.seats << sa
        end
        @canceled_order.save!
      end

      it "releases seats associated with non-holding orders" do
        count = SeatAssignment.release_temporary_holds_for_performance(performance1.id)

        expect(count).to eq(2)
        @abandoned_seats.each do |sa|
          sa.reload
          expect(sa.status).to eq(SeatAssignment::AVAILABLE)
          expect(sa.order_uuid).to be_nil
        end
      end
    end

    context "when there are ASSIGNED seats" do
      before do
        @assigned_seats = performance1.seat_assignments.take(2)
        @assigned_seats.each do |sa|
          sa.update!(status: SeatAssignment::ASSIGNED, order_uuid: SecureRandom.uuid)
        end
      end

      it "does NOT release ASSIGNED seats" do
        count = SeatAssignment.release_temporary_holds_for_performance(performance1.id)

        expect(count).to eq(0)
        @assigned_seats.each do |sa|
          sa.reload
          expect(sa.status).to eq(SeatAssignment::ASSIGNED)
          expect(sa.order_uuid).not_to be_nil
        end
      end
    end

    context "when releasing seats clears order_uuid and accessibility" do
      before do
        @seat_with_accessibility = performance1.seat_assignments.first
        @seat_with_accessibility.update!(
          status: SeatAssignment::TEMPORARY,
          order_uuid: SecureRandom.uuid,
          accessibility: 'wheelchair'
        )
      end

      it "clears both order_uuid and accessibility fields" do
        SeatAssignment.release_temporary_holds_for_performance(performance1.id)

        @seat_with_accessibility.reload
        expect(@seat_with_accessibility.order_uuid).to be_nil
        expect(@seat_with_accessibility.accessibility).to be_nil
      end
    end

    context "when scoping to specific performance" do
      before do
        # Create TEMPORARY seats in performance1
        @perf1_seats = performance1.seat_assignments.take(2)
        @perf1_seats.each do |sa|
          sa.update!(status: SeatAssignment::TEMPORARY, order_uuid: nil)
        end

        # Create TEMPORARY seats in performance2
        @perf2_seats = performance2.seat_assignments.take(2)
        @perf2_seats.each do |sa|
          sa.update!(status: SeatAssignment::TEMPORARY, order_uuid: nil)
        end
      end

      it "only releases seats for the specified performance" do
        count = SeatAssignment.release_temporary_holds_for_performance(performance1.id)

        expect(count).to eq(2)

        # Performance 1 seats should be released
        @perf1_seats.each do |sa|
          sa.reload
          expect(sa.status).to eq(SeatAssignment::AVAILABLE)
        end

        # Performance 2 seats should remain TEMPORARY
        @perf2_seats.each do |sa|
          sa.reload
          expect(sa.status).to eq(SeatAssignment::TEMPORARY)
        end
      end
    end

    context "when there is a mix of seat types" do
      before do
        seats = performance1.seat_assignments.take(6)

        # 2 orphaned TEMPORARY seats (should be released)
        @orphaned = seats[0..1]
        @orphaned.each do |sa|
          sa.update!(status: SeatAssignment::TEMPORARY, order_uuid: nil)
        end

        # 2 TEMPORARY seats with valid HOLD order (should NOT be released)
        ticket_class = performance1.ticket_class_allocations.first.ticket_class
        @valid_order = TicketOrder.new(
          status: Order::HOLD,
          performance: performance1,
          address: FactoryBot.create(:address),
          payment_type: FactoryBot.create(:cash_payment_type)
        )
        @valid_order.ticket_line_items << FactoryBot.build(:ticket_line_item,
                                                           ticket_class: ticket_class,
                                                           ticket_count: 2,
                                                           order: @valid_order)
        # Assign seats before saving to satisfy validation
        @valid_hold = seats[2..3]
        @valid_hold.each do |sa|
          sa.update!(status: SeatAssignment::TEMPORARY, order_uuid: @valid_order.uuid)
          @valid_order.seats << sa
        end
        @valid_order.save!

        # Ensure seats remain TEMPORARY (save! might have changed them to ASSIGNED)
        @valid_hold.each do |sa|
          sa.reload
          sa.update!(status: SeatAssignment::TEMPORARY) unless sa.status == SeatAssignment::TEMPORARY
        end

        # 2 ASSIGNED seats (should NOT be released)
        @assigned = seats[4..5]
        @assigned.each do |sa|
          sa.update!(status: SeatAssignment::ASSIGNED, order_uuid: SecureRandom.uuid)
        end
      end

      it "only releases the orphaned TEMPORARY seats" do
        count = SeatAssignment.release_temporary_holds_for_performance(performance1.id)

        expect(count).to eq(2)

        # Orphaned seats should be AVAILABLE
        @orphaned.each do |sa|
          sa.reload
          expect(sa.status).to eq(SeatAssignment::AVAILABLE)
        end

        # Valid hold seats should remain TEMPORARY
        @valid_hold.each do |sa|
          sa.reload
          expect(sa.status).to eq(SeatAssignment::TEMPORARY)
        end

        # Assigned seats should remain ASSIGNED
        @assigned.each do |sa|
          sa.reload
          expect(sa.status).to eq(SeatAssignment::ASSIGNED)
        end
      end
    end

    context "when there are no seats to release" do
      it "returns zero" do
        count = SeatAssignment.release_temporary_holds_for_performance(performance1.id)
        expect(count).to eq(0)
      end
    end
  end
end
