require "rails_helper"

RSpec.describe SeatManagementService, type: :service do
  # Helper to build a reserved-seating production with seat assignments
  # Returns a performance that already has SeatAssignments created.
  let(:production) { FactoryBot.create(:production_with_reserved_seating) }
  let(:performance) do
    perf = FactoryBot.create(:reserved_seating, production: production,
                                                performance_date: Date.today + 7.days,
                                                performance_time: Time.parse("19:00"))
    SeatAssignment.available_seat_assignments(perf)
    perf.reload
    perf
  end
  let(:order_uuid) { SecureRandom.uuid }

  # Helper: grab the requested number of available SeatAssignments from the performance
  def available_seat_ids(count = 1)
    performance.seat_assignments
               .select { |sa| sa.status == SeatAssignment::AVAILABLE }
               .first(count)
               .map(&:seat_id)
  end

  # Helper: a valid ticket class id for this performance
  def valid_ticket_class_id
    performance.ticket_class_allocations.find { |tca| tca.available }.ticket_class_id
  end

  subject(:service) { SeatManagementService.new(performance, order_uuid) }

  # ---------------------------------------------------------------------------
  # Result object
  # ---------------------------------------------------------------------------
  describe "Result" do
    let(:result) { SeatManagementService::Result.new }

    it "initializes with success=false, data=nil, error=nil" do
      expect(result.success).to be false
      expect(result.data).to be_nil
      expect(result.error).to be_nil
    end

    it "is a failure? on initialization" do
      expect(result.failure?).to be true
      expect(result.success?).to be false
    end

    describe "#success!" do
      it "sets success to true and stores data" do
        result.success!(key: "val")
        expect(result.success?).to be true
        expect(result.failure?).to be false
        expect(result.data).to eq(key: "val")
        expect(result.error).to be_nil
      end
    end

    describe "#fail!" do
      it "sets success to false and stores the error message" do
        result.fail!("something went wrong")
        expect(result.success?).to be false
        expect(result.failure?).to be true
        expect(result.error).to eq("something went wrong")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #assign_seats
  # ---------------------------------------------------------------------------
  describe "#assign_seats" do
    context "with an empty seats array" do
      it "returns a failure result with 'No seats specified'" do
        result = service.assign_seats([], valid_ticket_class_id)
        expect(result.failure?).to be true
        expect(result.error).to eq("No seats specified")
      end
    end

    context "with an invalid ticket_class_id" do
      it "returns a failure result with 'Invalid ticket class' when nil" do
        result = service.assign_seats(available_seat_ids(1), nil)
        expect(result.failure?).to be true
        expect(result.error).to eq("Invalid ticket class")
      end

      it "returns a failure result with 'Invalid ticket class' when id not in performance" do
        result = service.assign_seats(available_seat_ids(1), 999_999)
        expect(result.failure?).to be true
        expect(result.error).to eq("Invalid ticket class")
      end
    end

    context "with valid inputs" do
      it "returns a success result" do
        result = service.assign_seats(available_seat_ids(1), valid_ticket_class_id)
        expect(result.success?).to be true
        expect(result.error).to be_nil
      end

      it "result data includes :id, :status, :order_uuid, :current_seat_assignments" do
        result = service.assign_seats(available_seat_ids(1), valid_ticket_class_id)
        expect(result.data).to include(:id, :status, :order_uuid, :current_seat_assignments)
      end

      it "result data includes :unavailable and :ticket_count" do
        result = service.assign_seats(available_seat_ids(1), valid_ticket_class_id)
        expect(result.data).to include(:unavailable, :ticket_count)
      end

      it "marks the seat as TEMPORARY for the given order_uuid" do
        seat_id = available_seat_ids(1).first
        service.assign_seats([seat_id], valid_ticket_class_id)
        sa = SeatAssignment.find_by(seat_id: seat_id, performance_id: performance.id)
        expect(sa.status).to eq(SeatAssignment::TEMPORARY)
        expect(sa.order_uuid).to eq(order_uuid)
      end

      it "returns the order_uuid of the assignment in the result" do
        result = service.assign_seats(available_seat_ids(1), valid_ticket_class_id)
        expect(result.data[:order_uuid]).to eq(order_uuid)
      end

      it "sets ticket_class_id on the seat assignment" do
        seat_id = available_seat_ids(1).first
        tc_id = valid_ticket_class_id
        service.assign_seats([seat_id], tc_id)
        sa = SeatAssignment.find_by(seat_id: seat_id, performance_id: performance.id)
        expect(sa.ticket_class_id).to eq(tc_id)
      end

      it "stores accessibility on the seat assignment when provided" do
        seat_id = available_seat_ids(1).first
        service.assign_seats([seat_id], valid_ticket_class_id, "wheelchair")
        sa = SeatAssignment.find_by(seat_id: seat_id, performance_id: performance.id)
        expect(sa.accessibility).to eq("wheelchair")
      end

      it "increments ticket_count in result data" do
        result = service.assign_seats(available_seat_ids(2), valid_ticket_class_id)
        expect(result.data[:ticket_count]).to be >= 1
      end
    end

    context "when all requested seat_ids are already taken by other orders" do
      before do
        other_uuid = SecureRandom.uuid
        seat_id = available_seat_ids(1).first
        sa = SeatAssignment.find_by(seat_id: seat_id, performance_id: performance.id)
        sa.update!(status: SeatAssignment::ASSIGNED, order_uuid: other_uuid)
        @taken_seat_ids = [seat_id]
      end

      it "returns a failure result with 'Some seats are not available'" do
        result = service.assign_seats(@taken_seat_ids, valid_ticket_class_id)
        expect(result.failure?).to be true
        expect(result.error).to eq("Some seats are not available")
      end
    end

    context "when only some of the requested seats are available" do
      # All-or-nothing: a request mixing an available and an already-taken seat
      # must fail rather than silently assigning just the free one.
      before do
        taken = available_seat_ids(1).first
        other_service = described_class.new(performance, SecureRandom.uuid)
        other_service.assign_seats([taken], valid_ticket_class_id)
        @taken_seat_id = taken
      end

      it "fails the whole request instead of assigning the available subset" do
        available = (available_seat_ids(5) - [@taken_seat_id]).first
        result = service.assign_seats([available, @taken_seat_id], valid_ticket_class_id)
        expect(result.failure?).to be true
        expect(result.error).to eq("Some seats are not available")
      end
    end

    context "when a requested seat_id is not part of this performance's seat map" do
      it "fails rather than assigning whatever subset is found" do
        valid = available_seat_ids(1).first
        result = service.assign_seats([valid, 999_999_999], valid_ticket_class_id)
        expect(result.failure?).to be true
        expect(result.error).to eq("Some seats are not available")
      end
    end

    context "when seat_ids belong to a different performance that shares the same seat map" do
      # CHARACTERIZATION NOTE: Because both performances share the same seat map,
      # the same seat_id exists in BOTH performances' SeatAssignments.
      # find_available_seats filters by seat_id AND performance_id (the service's
      # own performance), so the seat from the other performance IS found in the
      # current performance's SeatAssignments and can be successfully assigned.
      it "succeeds because the seat_id is shared across performances via the seat map" do
        other_performance = FactoryBot.create(:reserved_seating,
                                              production: production,
                                              performance_date: Date.today + 14.days,
                                              performance_time: Time.parse("19:00"))
        SeatAssignment.available_seat_assignments(other_performance)
        # A seat_id from the other performance also exists in the current performance
        other_seat_id = other_performance.seat_assignments.first.seat_id

        result = service.assign_seats([other_seat_id], valid_ticket_class_id)
        # The seat with this seat_id in the current performance is available, so
        # assignment succeeds.
        expect(result.success?).to be true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #release_seats
  # ---------------------------------------------------------------------------
  describe "#release_seats" do
    context "with an empty seats array" do
      it "returns a failure result with 'No seats specified'" do
        result = service.release_seats([])
        expect(result.failure?).to be true
        expect(result.error).to eq("No seats specified")
      end
    end

    context "when seats don't belong to this performance" do
      it "returns a failure result with 'No matching seats found for release'" do
        result = service.release_seats([99_999_999])
        expect(result.failure?).to be true
        expect(result.error).to eq("No matching seats found for release")
      end
    end

    context "when seats belong to a different order_uuid" do
      let(:other_uuid) { SecureRandom.uuid }
      let!(:seat_assignment) do
        seat_id = available_seat_ids(1).first
        sa = SeatAssignment.find_by(seat_id: seat_id, performance_id: performance.id)
        sa.update!(status: SeatAssignment::TEMPORARY, order_uuid: other_uuid)
        sa
      end

      it "returns a failure result with 'Cannot release seats from different order'" do
        result = service.release_seats([seat_assignment.seat_id])
        expect(result.failure?).to be true
        expect(result.error).to eq("Cannot release seats from different order")
      end
    end

    context "when seats belong to this order_uuid" do
      let!(:seat_assignment) do
        seat_id = available_seat_ids(1).first
        sa = SeatAssignment.find_by(seat_id: seat_id, performance_id: performance.id)
        sa.update!(status: SeatAssignment::TEMPORARY, order_uuid: order_uuid)
        sa
      end

      it "returns a success result" do
        result = service.release_seats([seat_assignment.seat_id])
        expect(result.success?).to be true
      end

      it "result data includes :id, :status, :order_uuid, :ticket_class_id" do
        result = service.release_seats([seat_assignment.seat_id])
        expect(result.data).to include(:id, :status, :order_uuid, :ticket_class_id)
      end

      it "result data includes :unavailable and :ticket_count" do
        result = service.release_seats([seat_assignment.seat_id])
        expect(result.data).to include(:unavailable, :ticket_count)
      end

      it "transitions the seat to RELEASING status via begin_release_from_order" do
        service.release_seats([seat_assignment.seat_id])
        seat_assignment.reload
        expect(seat_assignment.status).to eq(SeatAssignment::RELEASING)
      end

      it "still returns the order_uuid in result data" do
        result = service.release_seats([seat_assignment.seat_id])
        expect(result.data[:order_uuid]).to eq(order_uuid)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #confirm_seat_assignments
  # ---------------------------------------------------------------------------
  describe "#confirm_seat_assignments" do
    context "when there are no temporary seat assignments for the order" do
      it "returns a failure result with 'No temporary seats found to confirm'" do
        result = service.confirm_seat_assignments
        expect(result.failure?).to be true
        expect(result.error).to eq("No temporary seats found to confirm")
      end
    end

    context "when there is no Order record matching the order_uuid" do
      before do
        # Assign a seat temporarily so the first validation passes
        seat_id = available_seat_ids(1).first
        sa = SeatAssignment.find_by(seat_id: seat_id, performance_id: performance.id)
        sa.update!(status: SeatAssignment::TEMPORARY, order_uuid: order_uuid)
      end

      it "returns a failure result with 'Order not found'" do
        result = service.confirm_seat_assignments
        expect(result.failure?).to be true
        expect(result.error).to eq("Order not found")
      end
    end

    context "when the order exists but seat count doesn't match order.number_of_tickets" do
      let!(:ticket_order) do
        o = TicketOrder.new(
          performance: performance,
          address: FactoryBot.create(:address),
          payment_type: FactoryBot.create(:cash_payment_type),
          status: Order::NEW
        )
        o.uuid = order_uuid
        o.do_not_create_tasks = true
        tc = performance.ticket_class_allocations.find { |tca| tca.available }.ticket_class
        o.ticket_line_items << TicketLineItem.new(ticket_class: tc, ticket_count: 3)
        o.save!(validate: false)
        o
      end

      before do
        # Assign only 1 seat temporarily (order expects 3)
        seat_id = available_seat_ids(1).first
        sa = SeatAssignment.find_by(seat_id: seat_id, performance_id: performance.id)
        sa.update!(status: SeatAssignment::TEMPORARY, order_uuid: order_uuid)
      end

      it "returns a failure result with 'Seat count mismatch'" do
        result = service.confirm_seat_assignments
        expect(result.failure?).to be true
        expect(result.error).to eq("Seat count mismatch")
      end
    end

    context "when seats match the order ticket count" do
      let!(:ticket_order) do
        o = TicketOrder.new(
          performance: performance,
          address: FactoryBot.create(:address),
          payment_type: FactoryBot.create(:cash_payment_type),
          status: Order::NEW
        )
        o.uuid = order_uuid
        o.do_not_create_tasks = true
        tc = performance.ticket_class_allocations.find { |tca| tca.available }.ticket_class
        o.ticket_line_items << TicketLineItem.new(ticket_class: tc, ticket_count: 2)
        o.save!(validate: false)
        o
      end

      let!(:temp_assignments) do
        seat_ids = available_seat_ids(2)
        seat_ids.map do |seat_id|
          sa = SeatAssignment.find_by(seat_id: seat_id, performance_id: performance.id)
          sa.update!(status: SeatAssignment::TEMPORARY, order_uuid: order_uuid)
          sa
        end
      end

      it "returns a success result" do
        result = service.confirm_seat_assignments
        expect(result.success?).to be true
      end

      it "result data includes :status and :current_seat_assignments" do
        result = service.confirm_seat_assignments
        expect(result.data).to include(:status, :current_seat_assignments)
      end

      it "result data status is SeatAssignment::ASSIGNED" do
        result = service.confirm_seat_assignments
        expect(result.data[:status]).to eq(SeatAssignment::ASSIGNED)
      end

      it "transitions all TEMPORARY seats to ASSIGNED in the database" do
        service.confirm_seat_assignments
        temp_assignments.each do |sa|
          sa.reload
          expect(sa.status).to eq(SeatAssignment::ASSIGNED)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #begin_reseating
  # ---------------------------------------------------------------------------
  describe "#begin_reseating" do
    context "when the SeatAssignment record does not exist" do
      it "returns a failure result with 'Seat assignment not found'" do
        result = service.begin_reseating(99_999_999)
        expect(result.failure?).to be true
        expect(result.error).to eq("Seat assignment not found")
      end
    end

    context "when the seat assignment is assigned to this order" do
      let!(:seat_assignment) do
        seat_id = available_seat_ids(1).first
        sa = SeatAssignment.find_by(seat_id: seat_id, performance_id: performance.id)
        sa.update!(status: SeatAssignment::ASSIGNED, order_uuid: order_uuid)
        sa
      end

      it "returns a success result" do
        result = service.begin_reseating(seat_assignment.id)
        expect(result.success?).to be true
      end

      it "result data includes :id, :status, :order_uuid" do
        result = service.begin_reseating(seat_assignment.id)
        expect(result.data).to include(:id, :status, :order_uuid)
      end

      it "result data includes :ticket_class_id, :unavailable, :ticket_count" do
        result = service.begin_reseating(seat_assignment.id)
        expect(result.data).to include(:ticket_class_id, :unavailable, :ticket_count)
      end

      it "transitions the seat to RELEASING via begin_release_from_order" do
        service.begin_reseating(seat_assignment.id)
        seat_assignment.reload
        expect(seat_assignment.status).to eq(SeatAssignment::RELEASING)
      end
    end

    context "when the seat assignment is NOT assigned to this order" do
      let!(:other_sa) do
        other_uuid = SecureRandom.uuid
        seat_id = available_seat_ids(1).first
        sa = SeatAssignment.find_by(seat_id: seat_id, performance_id: performance.id)
        sa.update!(status: SeatAssignment::ASSIGNED, order_uuid: other_uuid)
        sa
      end

      it "returns a failure result with 'Seat is not assigned to this order'" do
        result = service.begin_reseating(other_sa.id)
        expect(result.failure?).to be true
        expect(result.error).to eq("Seat is not assigned to this order")
      end
    end

    context "when the seat is in AVAILABLE status (not assigned to anyone)" do
      let!(:available_sa) do
        seat_id = available_seat_ids(1).first
        SeatAssignment.find_by(seat_id: seat_id, performance_id: performance.id)
      end

      it "returns a failure result since the seat is not assigned to this order" do
        result = service.begin_reseating(available_sa.id)
        expect(result.failure?).to be true
        expect(result.error).to eq("Seat is not assigned to this order")
      end
    end

    context "when an unexpected error occurs during begin_release_from_order" do
      let!(:seat_assignment) do
        seat_id = available_seat_ids(1).first
        sa = SeatAssignment.find_by(seat_id: seat_id, performance_id: performance.id)
        sa.update!(status: SeatAssignment::ASSIGNED, order_uuid: order_uuid)
        sa
      end

      before do
        allow_any_instance_of(SeatAssignment).to receive(:begin_release_from_order)
          .and_raise(RuntimeError, "unexpected failure")
      end

      it "returns a failure result with the exception message (generic rescue branch)" do
        result = service.begin_reseating(seat_assignment.id)
        expect(result.failure?).to be true
        expect(result.error).to eq("unexpected failure")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Constructor / initialization
  # ---------------------------------------------------------------------------
  describe "#initialize" do
    it "stores the performance" do
      expect(service.performance).to eq(performance)
    end

    it "stores the order_uuid" do
      expect(service.order_uuid).to eq(order_uuid)
    end

    it "accepts nil order_uuid" do
      svc = SeatManagementService.new(performance, nil)
      expect(svc.order_uuid).to be_nil
    end
  end
end
